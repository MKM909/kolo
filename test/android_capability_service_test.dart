import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/services/android_capability_service.dart';
import 'package:kolo/data/services/android_permission_requester.dart';
import 'package:kolo/domain/models/models.dart';

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

  test(
    'reports notification listener enabled status from MethodChannel',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'isNotificationListenerEnabled');
            return true;
          });

      final service = AndroidCapabilityService(channel: channel);

      expect(await service.isNotificationListenerEnabled(), isTrue);
    },
  );

  test(
    'notifications request returns granted when listener is enabled after settings',
    () async {
      final capabilities = _FakeAndroidCapabilities(
        notificationListenerEnabled: true,
      );
      final requester = AndroidPermissionRequester(capabilities: capabilities);

      final state = await requester.request(KoloPermission.notifications);

      expect(capabilities.openedNotificationSettings, isTrue);
      expect(state, PermissionGrantState.granted);
    },
  );
}

class _FakeAndroidCapabilities extends AndroidCapabilityService {
  _FakeAndroidCapabilities({required this.notificationListenerEnabled});

  final bool notificationListenerEnabled;
  bool openedNotificationSettings = false;

  @override
  Future<bool> openNotificationListenerSettings() async {
    openedNotificationSettings = true;
    return true;
  }

  @override
  Future<bool> isNotificationListenerEnabled() async {
    return notificationListenerEnabled;
  }
}
