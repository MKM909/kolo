import 'dart:async';

import 'package:kolo/data/services/android_capability_service.dart';
import 'package:kolo/data/services/overlay_bubble_service.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';
import 'package:kolo/domain/services/spending_justification_advisor.dart';

class OverlayConversationBridge {
  OverlayConversationBridge({
    required OverlayBubbleService overlayBubble,
    required KoloRepository repository,
    required SpendingJustificationAdvisor spendingAdvisor,
    required Future<DashboardState> Function() loadDashboard,
    AndroidCapabilityService? androidCapabilities,
    DateTime Function()? now,
  }) : _overlayBubble = overlayBubble,
       _repository = repository,
       _spendingAdvisor = spendingAdvisor,
       _loadDashboard = loadDashboard,
       _androidCapabilities = androidCapabilities,
       _now = now ?? DateTime.now;

  final OverlayBubbleService _overlayBubble;
  final KoloRepository _repository;
  final SpendingJustificationAdvisor _spendingAdvisor;
  final Future<DashboardState> Function() _loadDashboard;
  final AndroidCapabilityService? _androidCapabilities;
  final DateTime Function() _now;
  StreamSubscription<Object?>? _subscription;

  void start() {
    _subscription ??= _overlayBubble.overlayMessages.listen(
      (message) => unawaited(_handleOverlayMessage(message)),
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _handleOverlayMessage(Object? message) async {
    if (message is! Map) return;
    final type = message['type']?.toString();
    if (type == 'blockCancelled') {
      await _androidCapabilities?.performGlobalBack();
      return;
    }
    if (type != 'userMessage') return;

    final text = message['text']?.toString().trim();
    if (text == null || text.isEmpty) return;

    final blockRequest = _OverlayBlockRequest.fromMap(message);
    if (blockRequest?.blockLevel == 'explain') {
      await _handleExplainBlockMessage(text, blockRequest!);
      return;
    }
    if (blockRequest?.blockLevel == 'hardLock') {
      if (!_looksLikeSpendIntent(text) && _amountKoboFrom(text) == null) {
        await _handleExplainBlockMessage(text, blockRequest!);
        return;
      }
      await _handleSpendMessage(text, blockRequest: blockRequest);
      return;
    }

    if (_looksLikeSpendIntent(text)) {
      await _handleSpendMessage(text);
      return;
    }

    await _handleChatMessage(text);
  }

  Future<void> _handleExplainBlockMessage(
    String text,
    _OverlayBlockRequest blockRequest,
  ) async {
    final now = _now();
    final response =
        'Reason logged for ${blockRequest.appName}. You can continue now.';
    await _recordOverlayConversation(
      userText: text,
      assistantText: response,
      now: now,
    );
    await _overlayBubble.sendAssistantMessageToOverlay(response);
    await _overlayBubble.sendBlockDecisionToOverlay(
      status: SpendingDecisionStatus.approved.name,
      message: response,
      appName: blockRequest.appName,
      packageName: blockRequest.packageName,
      blockLevel: blockRequest.blockLevel,
    );
  }

  Future<void> _handleSpendMessage(
    String text, {
    _OverlayBlockRequest? blockRequest,
  }) async {
    final amountKobo = _amountKoboFrom(text);
    if (amountKobo == null || amountKobo <= 0) {
      await _overlayBubble.sendAssistantMessageToOverlay(
        'Tell me the amount and what it is for, then I can check it against your Kolo budget.',
      );
      return;
    }

    try {
      final dashboard = await _loadDashboard();
      final now = _now();
      final transaction = TransactionRecord.expense(
        id: 'overlay-spend-${now.microsecondsSinceEpoch}',
        amountKobo: amountKobo,
        category: _categoryFor(text, dashboard),
        description: text,
        date: now,
        source: TransactionSource.watchedApp,
        merchantName: 'Kolo bubble',
      );
      final decision = await _spendingAdvisor.evaluateSpendingJustification(
        context: dashboard,
        transaction: transaction,
        justification: text,
        modelName: dashboard.profile.preferredAiModel,
      );

      await _recordOverlayConversation(
        userText: text,
        assistantText: decision.message,
        now: now,
      );
      await _overlayBubble.sendAssistantMessageToOverlay(decision.message);
      if (blockRequest != null) {
        await _overlayBubble.sendBlockDecisionToOverlay(
          status: decision.status.name,
          message: decision.message,
          appName: blockRequest.appName,
          packageName: blockRequest.packageName,
          blockLevel: blockRequest.blockLevel,
        );
      }
    } on Object {
      await _overlayBubble.sendAssistantMessageToOverlay(
        'I could not check that spend yet. Open Kolo and I will run the full budget check there.',
      );
    }
  }

  Future<void> _handleChatMessage(String text) async {
    try {
      final reply = await _repository.sendAiMessage(text);
      await _overlayBubble.sendAssistantMessageToOverlay(reply.content);
    } on Object {
      await _overlayBubble.sendAssistantMessageToOverlay(
        'I am listening, but I could not reach the full Kolo chat yet.',
      );
    }
  }

  Future<void> _recordOverlayConversation({
    required String userText,
    required String assistantText,
    required DateTime now,
  }) async {
    await _repository.recordAiMessage(
      AiMessage(
        id: 'overlay-user-${now.microsecondsSinceEpoch}',
        role: AiRole.user,
        content: userText,
        timestamp: now,
        context: 'overlay_spending_justification',
      ),
    );
    await _repository.recordAiMessage(
      AiMessage(
        id: 'overlay-assistant-${now.microsecondsSinceEpoch}',
        role: AiRole.assistant,
        content: assistantText,
        timestamp: now,
        context: 'overlay_spending_justification',
      ),
    );
  }

  bool _looksLikeSpendIntent(String text) {
    final lower = text.toLowerCase();
    return lower.contains('spend') ||
        lower.contains('buy') ||
        lower.contains('send') ||
        lower.contains('pay') ||
        lower.contains('transfer');
  }

  int? _amountKoboFrom(String text) {
    final match = RegExp(
      r'(?:₦|ngn|n)?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    final rawAmount = match?.group(1)?.replaceAll(',', '');
    if (rawAmount == null) return null;
    final naira = double.tryParse(rawAmount);
    if (naira == null) return null;
    return (naira * 100).round();
  }

  String _categoryFor(String text, DashboardState dashboard) {
    final lower = text.toLowerCase();
    final preferredCategory = switch (lower) {
      final value
          when value.contains('food') ||
              value.contains('lunch') ||
              value.contains('snack') ||
              value.contains('restaurant') =>
        'Food & Snacks',
      final value when value.contains('data') || value.contains('airtime') =>
        'Data & Airtime',
      final value
          when value.contains('bolt') ||
              value.contains('uber') ||
              value.contains('transport') =>
        'Transport',
      _ => 'Miscellaneous',
    };

    return dashboard.budgetPlan.categories
        .map((category) => category.name)
        .firstWhere(
          (category) =>
              category.toLowerCase() == preferredCategory.toLowerCase(),
          orElse: () => preferredCategory,
        );
  }
}

class _OverlayBlockRequest {
  const _OverlayBlockRequest({
    required this.appName,
    required this.packageName,
    required this.blockLevel,
  });

  final String appName;
  final String packageName;
  final String blockLevel;

  static _OverlayBlockRequest? fromMap(Map<Object?, Object?> map) {
    final blockLevel = map['blockLevel']?.toString().trim();
    if (blockLevel != 'explain' && blockLevel != 'hardLock') return null;
    final appName = map['appName']?.toString().trim();
    final packageName = map['packageName']?.toString().trim();
    if (appName == null ||
        appName.isEmpty ||
        packageName == null ||
        packageName.isEmpty) {
      return null;
    }
    return _OverlayBlockRequest(
      appName: appName,
      packageName: packageName,
      blockLevel: blockLevel!,
    );
  }
}
