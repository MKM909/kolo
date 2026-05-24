import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/repositories/fake_kolo_repository.dart';
import 'package:kolo/data/services/android_capability_service.dart';
import 'package:kolo/data/services/native_event_ingestor.dart';

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
    final ingestor = NativeEventIngestor(
      capabilities: AndroidCapabilityService(channel: channel),
      repository: repository,
    );

    final processed = await ingestor.drainAndProcess();
    final dashboard = await repository.watchDashboard().first;

    expect(processed, 1);
    expect(dashboard.transactions.first.id, 'native-sms-1');
    expect(dashboard.transactions.first.merchantName, 'Chicken Republic');
    expect(dashboard.transactions.first.amountKobo, 250000);
    expect(dashboard.balanceKobo, 5080000 - 250000);
  });
}
