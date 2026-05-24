import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/repositories/fake_kolo_repository.dart';
import 'package:kolo/data/services/android_capability_service.dart';
import 'package:kolo/data/services/native_event_ingestor.dart';
import 'package:kolo/data/services/overlay_bubble_service.dart';

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
  });
}

class _FakeOverlayBubbleService implements OverlayBubbleService {
  int showCalls = 0;

  @override
  Future<bool> showKoloBubble() async {
    showCalls += 1;
    return true;
  }

  @override
  Future<bool> requestPermission() async => true;
}
