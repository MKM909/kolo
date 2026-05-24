import 'package:kolo/data/services/android_capability_service.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/domain/services/transaction_parser.dart';

class NativeEventIngestor {
  const NativeEventIngestor({
    required AndroidCapabilityService capabilities,
    required KoloRepository repository,
  }) : _capabilities = capabilities,
       _repository = repository;

  final AndroidCapabilityService _capabilities;
  final KoloRepository _repository;

  Future<int> drainAndProcess() async {
    final events = await _capabilities.drainNativeEvents();
    var processed = 0;

    for (final event in events) {
      if (event.type == 'foreground_app') {
        if (await _processForegroundApp(event)) processed += 1;
        continue;
      }

      final rawText = _rawTextFor(event);
      if (rawText == null || rawText.trim().isEmpty) continue;

      final draft = TransactionParser.parse(rawText);
      if (draft == null) continue;

      await _repository.logTransaction(_transactionFromDraft(event, draft));
      processed += 1;
    }

    return processed;
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

    await _repository.recordAiMessage(
      AiMessage(
        id: 'native-${event.id}',
        role: AiRole.assistant,
        content:
            'You just opened ${watchedApp.displayName}. Your balance is ${MoneyFormatter.formatKobo(dashboard.balanceKobo)}. What are you about to do?',
        timestamp: event.createdAt,
        context: 'intervention',
      ),
    );
    return true;
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
