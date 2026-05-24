import 'package:kolo/data/services/android_capability_service.dart';
import 'package:kolo/data/services/overlay_bubble_service.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/domain/services/spending_intervention_advisor.dart';
import 'package:kolo/domain/services/transaction_categorizer.dart';
import 'package:kolo/domain/services/transaction_parser.dart';

class NativeEventIngestor {
  const NativeEventIngestor({
    required AndroidCapabilityService capabilities,
    required KoloRepository repository,
    OverlayBubbleService? overlayBubble,
    TransactionCategorizer? categorizer,
    SpendingInterventionAdvisor? interventionAdvisor,
  }) : _capabilities = capabilities,
       _repository = repository,
       _overlayBubble = overlayBubble,
       _categorizer = categorizer,
       _interventionAdvisor = interventionAdvisor;

  final AndroidCapabilityService _capabilities;
  final KoloRepository _repository;
  final OverlayBubbleService? _overlayBubble;
  final TransactionCategorizer? _categorizer;
  final SpendingInterventionAdvisor? _interventionAdvisor;

  Future<int> drainAndProcess() async {
    final events = await _capabilities.drainNativeEvents();
    final seenEventIds = <String>{};
    var processed = 0;

    for (final event in events) {
      if (!seenEventIds.add(event.id)) continue;

      if (event.type == 'foreground_app') {
        if (await _processForegroundApp(event)) processed += 1;
        continue;
      }

      if (event.type == 'notification_posted' &&
          !await _isEnabledWatchedApp(event)) {
        continue;
      }

      final rawText = _rawTextFor(event);
      if (rawText == null || rawText.trim().isEmpty) continue;

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
    await _overlayBubble?.showKoloBubble();
    return true;
  }

  Future<String> _interventionMessage({
    required DashboardState dashboard,
    required WatchedApp watchedApp,
  }) async {
    final advisor = _interventionAdvisor;
    if (advisor == null) return _fallbackIntervention(dashboard, watchedApp);

    try {
      final message = await advisor.interventionMessage(context: dashboard);
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
            date: event.createdAt,
            source: draft.source,
            merchantName: draft.merchantName,
          )
        : TransactionRecord.expense(
            id: id,
            amountKobo: draft.amountKobo,
            category: draft.category,
            description: description,
            date: event.createdAt,
            source: draft.source,
            merchantName: draft.merchantName,
          );
  }
}
