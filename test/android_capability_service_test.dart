import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/services/android_capability_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/kolo_android_capabilities');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('drains queued native Android events from MethodChannel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'drainNativeEvents');
          return [
            {
              'id': 'native-1',
              'type': 'sms_received',
              'createdAt': 123,
              'payload': {'body': 'GTBank Alert DR NGN2,500.00'},
            },
          ];
        });

    final service = AndroidCapabilityService(channel: channel);
    final events = await service.drainNativeEvents();

    expect(events.single.id, 'native-1');
    expect(events.single.type, 'sms_received');
    expect(events.single.createdAt, DateTime.fromMillisecondsSinceEpoch(123));
    expect(events.single.payload['body'], 'GTBank Alert DR NGN2,500.00');
  });
}
