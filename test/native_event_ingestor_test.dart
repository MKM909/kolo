import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/repositories/fake_kolo_repository.dart';
import 'package:kolo/data/services/android_capability_service.dart';
import 'package:kolo/data/services/native_event_ingestor.dart';
import 'package:kolo/data/services/overlay_bubble_service.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/sms_received_handler.dart';
import 'package:kolo/domain/services/spending_intervention_advisor.dart';
import 'package:kolo/domain/services/transaction_categorizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/kolo_native_ingestor');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('drains native SMS events into logged transactions', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'drainNativeEvents');
          return [
            {
              'id': 'sms-1',
              'type': 'sms_received',
              'createdAt': DateTime(2026, 5, 24).millisecondsSinceEpoch,
              'payload': {
                'body':
                    'GTBank Alert: Acct 0123456789 DR NGN2,500.00 at Chicken Republic. Bal: NGN47,500.00',
              },
            },
          ];
        });

    final repository = FakeKoloRepository.seeded();
    final overlayBubble = _FakeOverlayBubbleService();
    final ingestor = NativeEventIngestor(
      capabilities: AndroidCapabilityService(channel: channel),
      repository: repository,
      overlayBubble: overlayBubble,
    );

    final processed = await ingestor.drainAndProcess();
    final dashboard = await repository.watchDashboard().first;

    expect(processed, 1);
    expect(dashboard.transactions.first.id, 'native-sms-1');
    expect(dashboard.transactions.first.merchantName, 'Chicken Republic');
    expect(dashboard.transactions.first.amountKobo, 250000);
    expect(dashboard.balanceKobo, 5080000 - 250000);
    expect(overlayBubble.showCalls, 1);
  });

  test('uses parsed SMS dates for logged native transactions', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'drainNativeEvents');
          return [
            {
              'id': 'sms-date',
              'type': 'sms_received',
              'createdAt': DateTime(2026, 5, 24, 15).millisecondsSinceEpoch,
              'payload': {
                'body':
                    'GTBank Alert: Acct 0123456789 DR NGN2,500.00 at Chicken Republic. Date: 23-May-2026. Bal: NGN47,500.00',
              },
            },
          ];
        });

    final repository = FakeKoloRepository.seeded();
    final ingestor = NativeEventIngestor(
      capabilities: AndroidCapabilityService(channel: channel),
      repository: repository,
    );

    await ingestor.drainAndProcess();
    final dashboard = await repository.watchDashboard().first;

    expect(dashboard.transactions.first.id, 'native-sms-date');
    expect(dashboard.transactions.first.date, DateTime(2026, 5, 23));
  });

  test('does not apply the same native event twice', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'drainNativeEvents');
          return [
            {
              'id': 'sms-dupe',
              'type': 'sms_received',
              'createdAt': DateTime(2026, 5, 24).millisecondsSinceEpoch,
              'payload': {
                'body':
                    'GTBank Alert: Acct 0123456789 DR NGN2,500.00 at Chicken Republic. Bal: NGN47,500.00',
              },
            },
            {
              'id': 'sms-dupe',
              'type': 'sms_received',
              'createdAt': DateTime(2026, 5, 24).millisecondsSinceEpoch,
              'payload': {
                'body':
                    'GTBank Alert: Acct 0123456789 DR NGN2,500.00 at Chicken Republic. Bal: NGN47,500.00',
              },
            },
          ];
        });

    final repository = FakeKoloRepository.seeded();
    final overlayBubble = _FakeOverlayBubbleService();
    final ingestor = NativeEventIngestor(
      capabilities: AndroidCapabilityService(channel: channel),
      repository: repository,
      overlayBubble: overlayBubble,
    );

    final processed = await ingestor.drainAndProcess();
    final dashboard = await repository.watchDashboard().first;

    expect(processed, 1);
    expect(
      dashboard.transactions.where((tx) => tx.id == 'native-sms-dupe'),
      hasLength(1),
    );
    expect(dashboard.balanceKobo, 5080000 - 250000);
    expect(overlayBubble.showCalls, 1);
  });

  test(
    'drains watched foreground app events into intervention messages',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'drainNativeEvents');
            return [
              {
                'id': 'app-1',
                'type': 'foreground_app',
                'createdAt': DateTime(2026, 5, 24, 10).millisecondsSinceEpoch,
                'payload': {'packageName': 'com.kuda.android'},
              },
            ];
          });

      final repository = FakeKoloRepository.seeded();
      final ingestor = NativeEventIngestor(
        capabilities: AndroidCapabilityService(channel: channel),
        repository: repository,
      );

      final processed = await ingestor.drainAndProcess();
      final dashboard = await repository.watchDashboard().first;

      expect(processed, 1);
      expect(dashboard.aiMessages.first.id, 'native-app-1');
      expect(dashboard.aiMessages.first.context, 'intervention');
      expect(dashboard.aiMessages.first.content, contains('Kuda'));
      expect(dashboard.aiMessages.first.content, contains('50,800.00'));
      expect(
        dashboard.aiMessages.first.content,
        contains('What are you about to do?'),
      );
    },
  );

  test('uses Gemini intervention copy for watched foreground apps', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'drainNativeEvents');
          return [
            {
              'id': 'app-gemini-1',
              'type': 'foreground_app',
              'createdAt': DateTime(2026, 5, 24, 10).millisecondsSinceEpoch,
              'payload': {'packageName': 'com.kuda.android'},
            },
          ];
        });

    final repository = FakeKoloRepository.seeded();
    await repository.updatePreferredAiModel('gemini-3.1-flash');
    final advisor = _FakeSpendingInterventionAdvisor(
      message: 'Kolo from Gemini: pause before sending money.',
    );
    final ingestor = NativeEventIngestor(
      capabilities: AndroidCapabilityService(channel: channel),
      repository: repository,
      interventionAdvisor: advisor,
    );

    final processed = await ingestor.drainAndProcess();
    final dashboard = await repository.watchDashboard().first;

    expect(processed, 1);
    expect(advisor.calls, 1);
    expect(advisor.lastContext?.balanceKobo, 5080000);
    expect(advisor.lastModelName, 'gemini-3.1-flash');
    expect(dashboard.aiMessages.first.content, advisor.message);
    expect(dashboard.aiMessages.first.context, 'intervention');
  });

  test('generates weekly insights from reminder native events', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'drainNativeEvents');
          return [
            {
              'id': 'weekly-reminder-1',
              'type': 'reminder',
              'createdAt': DateTime(2026, 5, 25, 9).millisecondsSinceEpoch,
              'payload': {'kind': 'weeklyInsight'},
            },
          ];
        });

    final repository = FakeKoloRepository.seeded();
    final overlayBubble = _FakeOverlayBubbleService();
    final before = await repository.watchDashboard().first;
    final ingestor = NativeEventIngestor(
      capabilities: AndroidCapabilityService(channel: channel),
      repository: repository,
      overlayBubble: overlayBubble,
    );

    final processed = await ingestor.drainAndProcess();
    final after = await repository.watchDashboard().first;

    expect(processed, 1);
    expect(after.insights, hasLength(before.insights.length + 1));
    expect(after.insights.first.title, 'Kolo weekly spending check');
    expect(overlayBubble.showCalls, 1);
    expect(overlayBubble.assistantMessages.single, contains('weekly insight'));
  });

  test('triggers the floating bubble for watched app interventions', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'drainNativeEvents');
          return [
            {
              'id': 'app-2',
              'type': 'foreground_app',
              'createdAt': DateTime(2026, 5, 24, 10).millisecondsSinceEpoch,
              'payload': {'packageName': 'com.kuda.android'},
            },
          ];
        });

    final repository = FakeKoloRepository.seeded();
    final overlayBubble = _FakeOverlayBubbleService();
    final ingestor = NativeEventIngestor(
      capabilities: AndroidCapabilityService(channel: channel),
      repository: repository,
      overlayBubble: overlayBubble,
    );

    final processed = await ingestor.drainAndProcess();

    expect(processed, 1);
    expect(overlayBubble.showCalls, 1);
    expect(overlayBubble.expandCalls, 1);
    expect(overlayBubble.assistantMessages.single, contains('Kuda'));
  });

  test('routes hard lock watched app events to a block overlay', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'drainNativeEvents');
          return [
            {
              'id': 'app-hard-lock-1',
              'type': 'foreground_app',
              'createdAt': DateTime(2026, 5, 24, 10).millisecondsSinceEpoch,
              'payload': {'packageName': 'com.kuda.android'},
            },
          ];
        });

    final repository = FakeKoloRepository.seeded();
    await repository.upsertWatchedApp(
      const WatchedApp(
        packageName: 'com.kuda.android',
        displayName: 'Kuda',
        enabled: true,
        blockLevel: WatchedAppBlockLevel.hardLock,
      ),
    );
    final overlayBubble = _FakeOverlayBubbleService();
    final ingestor = NativeEventIngestor(
      capabilities: AndroidCapabilityService(channel: channel),
      repository: repository,
      overlayBubble: overlayBubble,
    );

    final processed = await ingestor.drainAndProcess();

    expect(processed, 1);
    expect(overlayBubble.showCalls, 0);
    expect(overlayBubble.expandCalls, 0);
    expect(overlayBubble.blockOverlays.single.appName, 'Kuda');
    expect(
      overlayBubble.blockOverlays.single.blockLevel,
      WatchedAppBlockLevel.hardLock,
    );
    expect(overlayBubble.blockOverlays.single.prompt, contains('Kuda'));
  });

  test(
    'uses Gemini categorization when local notification parsing fails',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'drainNativeEvents');
            return [
              {
                'id': 'notif-ai-1',
                'type': 'notification_posted',
                'createdAt': DateTime(2026, 5, 24, 11).millisecondsSinceEpoch,
                'payload': {
                  'packageName': 'com.kuda.android',
                  'title': 'Kuda',
                  'text':
                      'Your payment to Shoprite for two thousand naira was successful.',
                },
              },
            ];
          });

      final repository = FakeKoloRepository.seeded();
      await repository.updatePreferredAiModel('gemini-3.1-pro');
      final overlayBubble = _FakeOverlayBubbleService();
      final categorizer = _FakeTransactionCategorizer(
        draft: const TransactionDraft(
          amountKobo: 200000,
          type: TransactionType.expense,
          merchantName: 'Shoprite',
          source: TransactionSource.notification,
          rawText:
              'Kuda Your payment to Shoprite for two thousand naira was successful.',
          category: 'Food & Snacks',
        ),
      );
      final ingestor = NativeEventIngestor(
        capabilities: AndroidCapabilityService(channel: channel),
        repository: repository,
        overlayBubble: overlayBubble,
        categorizer: categorizer,
      );

      final processed = await ingestor.drainAndProcess();
      final dashboard = await repository.watchDashboard().first;

      expect(processed, 1);
      expect(categorizer.calls, 1);
      expect(categorizer.lastSource, TransactionSource.notification);
      expect(categorizer.lastContext?.balanceKobo, 5080000);
      expect(categorizer.lastModelName, 'gemini-3.1-pro');
      expect(dashboard.transactions.first.id, 'native-notif-ai-1');
      expect(dashboard.transactions.first.merchantName, 'Shoprite');
      expect(dashboard.transactions.first.amountKobo, 200000);
      expect(dashboard.transactions.first.category, 'Food & Snacks');
      expect(overlayBubble.showCalls, 1);
    },
  );

  test('uses server SMS ingestion before local logging when available', () async {
    final createdAt = DateTime(2026, 5, 24, 11);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'drainNativeEvents');
          return [
            {
              'id': 'sms-server-1',
              'type': 'sms_received',
              'createdAt': createdAt.millisecondsSinceEpoch,
              'payload': {
                'sender': 'GTBank',
                'body':
                    'GTBank Alert: Acct 0123456789 DR NGN2,500.00 at Chicken Republic. Bal: NGN47,500.00',
              },
            },
          ];
        });

    final repository = FakeKoloRepository.seeded();
    await repository.updatePreferredAiModel('gemini-3.1-flash-lite');
    final initial = await repository.watchDashboard().first;
    final handler = _FakeSmsReceivedHandler(accepted: true);
    final overlayBubble = _FakeOverlayBubbleService();
    final ingestor = NativeEventIngestor(
      capabilities: AndroidCapabilityService(channel: channel),
      repository: repository,
      overlayBubble: overlayBubble,
      smsReceivedHandler: handler,
    );

    final processed = await ingestor.drainAndProcess();
    final dashboard = await repository.watchDashboard().first;

    expect(processed, 1);
    expect(handler.calls, 1);
    expect(handler.lastRawText, contains('Chicken Republic'));
    expect(handler.lastSender, 'GTBank');
    expect(handler.lastReceivedAt, createdAt);
    expect(handler.lastContext?.balanceKobo, initial.balanceKobo);
    expect(handler.lastModelName, 'gemini-3.1-flash-lite');
    expect(dashboard.transactions, hasLength(initial.transactions.length));
    expect(dashboard.balanceKobo, initial.balanceKobo);
    expect(overlayBubble.showCalls, 1);
  });

  test('falls back to local SMS logging when server ingestion fails', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'drainNativeEvents');
          return [
            {
              'id': 'sms-server-fallback',
              'type': 'sms_received',
              'createdAt': DateTime(2026, 5, 24).millisecondsSinceEpoch,
              'payload': {
                'body':
                    'GTBank Alert: Acct 0123456789 DR NGN2,500.00 at Chicken Republic. Bal: NGN47,500.00',
              },
            },
          ];
        });

    final repository = FakeKoloRepository.seeded();
    final handler = _FakeSmsReceivedHandler(accepted: false);
    final overlayBubble = _FakeOverlayBubbleService();
    final ingestor = NativeEventIngestor(
      capabilities: AndroidCapabilityService(channel: channel),
      repository: repository,
      overlayBubble: overlayBubble,
      smsReceivedHandler: handler,
    );

    final processed = await ingestor.drainAndProcess();
    final dashboard = await repository.watchDashboard().first;

    expect(processed, 1);
    expect(handler.calls, 1);
    expect(dashboard.transactions.first.id, 'native-sms-server-fallback');
    expect(dashboard.transactions.first.merchantName, 'Chicken Republic');
    expect(dashboard.balanceKobo, 5080000 - 250000);
    expect(overlayBubble.showCalls, 1);
  });

  test('ignores transaction-like notifications from unwatched apps', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'drainNativeEvents');
          return [
            {
              'id': 'notif-whatsapp-1',
              'type': 'notification_posted',
              'createdAt': DateTime(2026, 5, 24, 12).millisecondsSinceEpoch,
              'payload': {
                'packageName': 'com.whatsapp',
                'title': 'WhatsApp',
                'text': 'Timi: send me NGN2,500 for lunch',
              },
            },
          ];
        });

    final repository = FakeKoloRepository.seeded();
    final initial = await repository.watchDashboard().first;
    final overlayBubble = _FakeOverlayBubbleService();
    final ingestor = NativeEventIngestor(
      capabilities: AndroidCapabilityService(channel: channel),
      repository: repository,
      overlayBubble: overlayBubble,
    );

    final processed = await ingestor.drainAndProcess();
    final dashboard = await repository.watchDashboard().first;

    expect(processed, 0);
    expect(dashboard.transactions, hasLength(initial.transactions.length));
    expect(dashboard.balanceKobo, initial.balanceKobo);
    expect(overlayBubble.showCalls, 0);
  });

  test('prompts manual categorization when SMS parsing fails', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'drainNativeEvents');
          return [
            {
              'id': 'sms-unrecognized-1',
              'type': 'sms_received',
              'createdAt': DateTime(2026, 5, 24, 13).millisecondsSinceEpoch,
              'payload': {
                'body':
                    'Bank alert: your account changed after a card payment. Please check your app.',
              },
            },
          ];
        });

    final repository = FakeKoloRepository.seeded();
    final initial = await repository.watchDashboard().first;
    final overlayBubble = _FakeOverlayBubbleService();
    final ingestor = NativeEventIngestor(
      capabilities: AndroidCapabilityService(channel: channel),
      repository: repository,
      overlayBubble: overlayBubble,
    );

    final processed = await ingestor.drainAndProcess();
    final dashboard = await repository.watchDashboard().first;

    expect(processed, 1);
    expect(dashboard.transactions, hasLength(initial.transactions.length));
    expect(
      dashboard.aiMessages.first.id,
      'native-unrecognized-sms-unrecognized-1',
    );
    expect(dashboard.aiMessages.first.context, 'unrecognized_transaction');
    expect(dashboard.aiMessages.first.content, contains('categorize'));
    expect(overlayBubble.showCalls, 1);
  });
}

class _FakeTransactionCategorizer implements TransactionCategorizer {
  _FakeTransactionCategorizer({required this.draft});

  final TransactionDraft? draft;
  int calls = 0;
  TransactionSource? lastSource;
  DashboardState? lastContext;
  String? lastModelName;

  @override
  Future<TransactionDraft?> categorizeTransaction({
    required String rawText,
    required TransactionSource source,
    required DashboardState context,
    String? modelName,
  }) async {
    calls += 1;
    lastSource = source;
    lastContext = context;
    lastModelName = modelName;
    return draft;
  }
}

class _FakeSpendingInterventionAdvisor implements SpendingInterventionAdvisor {
  _FakeSpendingInterventionAdvisor({required this.message});

  final String message;
  int calls = 0;
  DashboardState? lastContext;
  String? lastModelName;

  @override
  Future<String> interventionMessage({
    required DashboardState context,
    String? modelName,
  }) async {
    calls += 1;
    lastContext = context;
    lastModelName = modelName;
    return message;
  }
}

class _FakeSmsReceivedHandler implements SmsReceivedHandler {
  _FakeSmsReceivedHandler({required this.accepted});

  final bool accepted;
  int calls = 0;
  String? lastRawText;
  String? lastSender;
  DateTime? lastReceivedAt;
  DashboardState? lastContext;
  String? lastModelName;

  @override
  Future<bool> onSmsReceived({
    required String rawText,
    String? sender,
    DateTime? receivedAt,
    required DashboardState context,
    String? modelName,
  }) async {
    calls += 1;
    lastRawText = rawText;
    lastSender = sender;
    lastReceivedAt = receivedAt;
    lastContext = context;
    lastModelName = modelName;
    return accepted;
  }
}

class _FakeOverlayBubbleService implements OverlayBubbleService {
  int showCalls = 0;
  int expandCalls = 0;
  final List<String> assistantMessages = [];
  final List<
    ({
      String appName,
      String packageName,
      WatchedAppBlockLevel blockLevel,
      String prompt,
    })
  >
  blockOverlays = [];

  @override
  Future<bool> isPermissionGranted() async => true;

  @override
  Future<bool> showKoloBubble() async {
    showCalls += 1;
    return true;
  }

  @override
  Future<bool> showBlockOverlay({
    required String appName,
    required String packageName,
    required WatchedAppBlockLevel blockLevel,
    required String prompt,
  }) async {
    blockOverlays.add((
      appName: appName,
      packageName: packageName,
      blockLevel: blockLevel,
      prompt: prompt,
    ));
    return true;
  }

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool?> expandConversation() async {
    expandCalls += 1;
    return true;
  }

  @override
  Future<bool?> collapseToBubble() async => true;

  @override
  Future<Object?> sendPromptToOverlay(String prompt) async => null;

  @override
  Future<Object?> sendAssistantMessageToOverlay(String message) async {
    assistantMessages.add(message);
    return null;
  }

  @override
  Future<Object?> sendBlockDecisionToOverlay({
    required String status,
    required String message,
    required String appName,
    required String packageName,
    required String blockLevel,
  }) async => null;

  @override
  Stream<Object?> get overlayMessages => const Stream.empty();
}
