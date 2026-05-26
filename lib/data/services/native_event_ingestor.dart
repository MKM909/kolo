import 'package:kolo/data/services/android_capability_service.dart';
import 'package:kolo/data/services/android_native_event_queue_store.dart';
import 'package:kolo/data/services/overlay_bubble_service.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/domain/services/native_event_queue_store.dart';
import 'package:kolo/domain/services/sms_received_handler.dart';
import 'package:kolo/domain/services/spending_intervention_advisor.dart';
import 'package:kolo/domain/services/transaction_categorizer.dart';
import 'package:kolo/domain/services/transaction_parser.dart';

class NativeEventIngestor {
  NativeEventIngestor({
    required AndroidCapabilityService capabilities,
    required KoloRepository repository,
    NativeEventQueueStore? eventQueueStore,
    OverlayBubbleService? overlayBubble,
    TransactionCategorizer? categorizer,
    SpendingInterventionAdvisor? interventionAdvisor,
    SmsReceivedHandler? smsReceivedHandler,
  }) : _eventQueueStore =
           eventQueueStore ??
           AndroidNativeEventQueueStore(capabilities: capabilities),
       _repository = repository,
       _overlayBubble = overlayBubble,
       _categorizer = categorizer,
       _interventionAdvisor = interventionAdvisor,
       _smsReceivedHandler = smsReceivedHandler;

  final NativeEventQueueStore _eventQueueStore;
  final KoloRepository _repository;
  final OverlayBubbleService? _overlayBubble;
  final TransactionCategorizer? _categorizer;
  final SpendingInterventionAdvisor? _interventionAdvisor;
  final SmsReceivedHandler? _smsReceivedHandler;

  Future<int> drainAndProcess() async {
    final events = await _eventQueueStore.drain();
    final seenEventIds = <String>{};
    var processed = 0;

    for (final event in events) {
      if (!seenEventIds.add(event.id)) continue;

      if (event.type == 'foreground_app') {
        if (await _processForegroundApp(event)) processed += 1;
        continue;
      }

      if (event.type == 'reminder') {
        if (await _processReminder(event)) processed += 1;
        continue;
      }

      if (event.type == 'notification_posted' &&
          !await _isEnabledWatchedApp(event)) {
        continue;
      }

      final rawText = _rawTextFor(event);
      if (rawText == null || rawText.trim().isEmpty) continue;

      if (event.type == 'sms_received' &&
          await _processServerSms(event, rawText)) {
        await _overlayBubble?.showKoloBubble();
        processed += 1;
        continue;
      }

      final draft =
          TransactionParser.parse(rawText) ?? await _aiDraft(event, rawText);
      if (draft == null) {
        await _recordUnrecognizedTransaction(event);
        await _overlayBubble?.showKoloBubble();
        processed += 1;
        continue;
      }

      await _repository.logTransaction(_transactionFromDraft(event, draft));
      await _overlayBubble?.showKoloBubble();
      processed += 1;
    }

    return processed;
  }

  Future<bool> _processServerSms(
    NativeAndroidEvent event,
    String rawText,
  ) async {
    final smsReceivedHandler = _smsReceivedHandler;
    if (smsReceivedHandler == null) return false;

    final context = await _repository.watchDashboard().first;
    return smsReceivedHandler.onSmsReceived(
      rawText: rawText,
      sender: event.payload['sender'] as String?,
      receivedAt: event.createdAt,
      context: context,
      modelName: context.profile.preferredAiModel,
    );
  }

  Future<TransactionDraft?> _aiDraft(
    NativeAndroidEvent event,
    String rawText,
  ) async {
    final categorizer = _categorizer;
    if (categorizer == null) return null;

    final context = await _repository.watchDashboard().first;
    return categorizer.categorizeTransaction(
      rawText: rawText,
      source: _sourceFor(event),
      context: context,
      modelName: context.profile.preferredAiModel,
    );
  }

  Future<void> _recordUnrecognizedTransaction(NativeAndroidEvent event) async {
    await _repository.recordAiMessage(
      AiMessage(
        id: 'native-unrecognized-${event.id}',
        role: AiRole.assistant,
        content:
            'I saw a money alert I could not read clearly. Please categorize it manually so your balance stays accurate.',
        timestamp: event.createdAt,
        context: 'unrecognized_transaction',
      ),
    );
  }

  Future<bool> _isEnabledWatchedApp(NativeAndroidEvent event) async {
    final packageName = event.payload['packageName'] as String?;
    if (packageName == null || packageName.isEmpty) return false;

    final dashboard = await _repository.watchDashboard().first;
    return dashboard.watchedApps.any(
      (app) => app.packageName == packageName && app.enabled,
    );
  }

  Future<bool> _processForegroundApp(NativeAndroidEvent event) async {
    final packageName = event.payload['packageName'] as String?;
    if (packageName == null || packageName.isEmpty) return false;

    final dashboard = await _repository.watchDashboard().first;
    WatchedApp? watchedApp;
    for (final app in dashboard.watchedApps) {
      if (app.packageName == packageName) {
        watchedApp = app;
        break;
      }
    }
    if (watchedApp == null || !watchedApp.enabled) return false;

    final content = await _interventionMessage(
      dashboard: dashboard,
      watchedApp: watchedApp,
    );

    await _repository.recordAiMessage(
      AiMessage(
        id: 'native-${event.id}',
        role: AiRole.assistant,
        content: content,
        timestamp: event.createdAt,
        context: 'intervention',
      ),
    );
    await _surfaceOverlayIntervention(content, watchedApp);
    return true;
  }

  Future<bool> _processReminder(NativeAndroidEvent event) async {
    if (event.payload['kind'] != 'weeklyInsight') return false;

    try {
      final insight = await _repository.generateWeeklyInsight();
      final message = 'Your weekly insight is ready: ${insight.title}.';
      await _overlayBubble?.showKoloBubble();
      await _overlayBubble?.sendAssistantMessageToOverlay(message);
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _surfaceOverlayIntervention(
    String content,
    WatchedApp watchedApp,
  ) async {
    final overlayBubble = _overlayBubble;
    if (overlayBubble == null) return;

    try {
      if (watchedApp.blockLevel != WatchedAppBlockLevel.soft) {
        await overlayBubble.showBlockOverlay(
          appName: watchedApp.displayName,
          packageName: watchedApp.packageName,
          blockLevel: watchedApp.blockLevel,
          prompt: content,
        );
        return;
      }

      await overlayBubble.showKoloBubble();
      await overlayBubble.sendAssistantMessageToOverlay(content);
      await overlayBubble.expandConversation();
    } on Object {
      // Native event processing should not fail just because the overlay
      // channel is unavailable or permission was revoked.
    }
  }

  Future<String> _interventionMessage({
    required DashboardState dashboard,
    required WatchedApp watchedApp,
  }) async {
    final advisor = _interventionAdvisor;
    if (advisor == null) return _fallbackIntervention(dashboard, watchedApp);

    try {
      final message = await advisor.interventionMessage(
        context: dashboard,
        modelName: dashboard.profile.preferredAiModel,
      );
      if (message.trim().isNotEmpty) return message;
    } on Object {
      // Keep native interventions useful if Functions or Gemini is unavailable.
    }
    return _fallbackIntervention(dashboard, watchedApp);
  }

  String _fallbackIntervention(
    DashboardState dashboard,
    WatchedApp watchedApp,
  ) {
    return 'You just opened ${watchedApp.displayName}. Your balance is ${MoneyFormatter.formatKobo(dashboard.balanceKobo)}. What are you about to do?';
  }

  TransactionSource _sourceFor(NativeAndroidEvent event) {
    return switch (event.type) {
      'notification_posted' => TransactionSource.notification,
      'sms_received' => TransactionSource.sms,
      _ => TransactionSource.manual,
    };
  }

  String? _rawTextFor(NativeAndroidEvent event) {
    return switch (event.type) {
      'sms_received' => event.payload['body'] as String?,
      'notification_posted' => [
        event.payload['title'],
        event.payload['text'],
      ].whereType<String>().join(' ').trim(),
      _ => null,
    };
  }

  TransactionRecord _transactionFromDraft(
    NativeAndroidEvent event,
    TransactionDraft draft,
  ) {
    final id = 'native-${event.id}';
    final description = draft.merchantName.isEmpty
        ? 'Native transaction'
        : draft.merchantName;

    return draft.type == TransactionType.income
        ? TransactionRecord.income(
            id: id,
            amountKobo: draft.amountKobo,
            category: draft.category,
            description: description,
            date: draft.occurredAt ?? event.createdAt,
            source: draft.source,
            merchantName: draft.merchantName,
          )
        : TransactionRecord.expense(
            id: id,
            amountKobo: draft.amountKobo,
            category: draft.category,
            description: description,
            date: draft.occurredAt ?? event.createdAt,
            source: draft.source,
            merchantName: draft.merchantName,
          );
  }
}
