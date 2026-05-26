import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/services/android_capability_service.dart';
import 'package:kolo/data/services/android_permission_requester.dart';
import 'package:kolo/data/services/kolo_background_service.dart';
import 'package:kolo/data/services/overlay_bubble_service.dart';
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
    'peeks and appends native Android events through MethodChannel',
    () async {
      final appended = <Map<dynamic, dynamic>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'enqueueNativeEvent') {
              appended.add(call.arguments as Map<dynamic, dynamic>);
              return null;
            }
            expect(call.method, 'peekNativeEvents');
            return [
              {
                'id': 'native-peek-1',
                'type': 'foreground_app',
                'createdAt': 456,
                'payload': {'packageName': 'com.kuda.android'},
              },
            ];
          });

      final service = AndroidCapabilityService(channel: channel);
      final event = NativeAndroidEvent(
        id: 'native-append-1',
        type: 'sms_received',
        createdAt: DateTime.fromMillisecondsSinceEpoch(123),
        payload: const {'body': 'Kuda debit NGN 1,000'},
      );

      await service.enqueueNativeEvent(event);
      final preview = await service.peekNativeEvents();

      expect(appended.single['id'], 'native-append-1');
      expect(appended.single['createdAt'], 123);
      expect(preview.single.id, 'native-peek-1');
      expect(preview.single.payload['packageName'], 'com.kuda.android');
    },
  );

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

  test(
    'reports accessibility service enabled status from MethodChannel',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'isAccessibilityServiceEnabled');
            return true;
          });

      final service = AndroidCapabilityService(channel: channel);

      expect(await service.isAccessibilityServiceEnabled(), isTrue);
    },
  );

  test(
    'accessibility request returns granted when service is enabled after settings',
    () async {
      final capabilities = _FakeAndroidCapabilities(
        notificationListenerEnabled: false,
        accessibilityServiceEnabled: true,
      );
      final requester = AndroidPermissionRequester(capabilities: capabilities);

      final state = await requester.request(KoloPermission.accessibility);

      expect(capabilities.openedAccessibilitySettings, isTrue);
      expect(state, PermissionGrantState.granted);
    },
  );

  test('starts the Android background watcher from MethodChannel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'startBackgroundWatcher');
          return true;
        });

    final service = AndroidCapabilityService(channel: channel);

    expect(await service.startBackgroundWatcher(), isTrue);
  });

  test(
    'maps installed app candidates from MethodChannel with finance apps first',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'getInstalledAppCandidates');
            return [
              {
                'packageName': 'com.android.calculator2',
                'displayName': 'Calculator',
                'installed': true,
                'isKnownFinancialApp': false,
              },
              {
                'packageName': 'com.kuda.android',
                'displayName': 'Kuda',
                'installed': true,
                'isKnownFinancialApp': true,
              },
              {
                'packageName': 'team.opay.pay',
                'displayName': 'Opay',
                'installed': false,
                'isKnownFinancialApp': true,
              },
            ];
          });

      final service = AndroidCapabilityService(channel: channel);
      final candidates = await service.getInstalledAppCandidates();

      expect(candidates.map((app) => app.packageName), [
        'com.kuda.android',
        'team.opay.pay',
        'com.android.calculator2',
      ]);
      expect(candidates.first.installed, isTrue);
      expect(candidates.first.isKnownFinancialApp, isTrue);
    },
  );

  test('background service request starts watcher before granting', () async {
    final capabilities = _FakeAndroidCapabilities(
      notificationListenerEnabled: false,
      backgroundWatcherStarted: true,
    );
    final backgroundService = _FakeKoloBackgroundServiceController();
    final requester = AndroidPermissionRequester(
      capabilities: capabilities,
      backgroundService: backgroundService,
    );

    final state = await requester.request(KoloPermission.backgroundService);

    expect(backgroundService.configureCalls, 1);
    expect(backgroundService.startCalls, 1);
    expect(capabilities.startedBackgroundWatcher, isTrue);
    expect(state, PermissionGrantState.granted);
  });

  test('overlay request uses the overlay window permission flow', () async {
    final overlayBubble = _FakeOverlayBubbleService(requestResult: true);
    final requester = AndroidPermissionRequester(
      capabilities: _FakeAndroidCapabilities(
        notificationListenerEnabled: false,
      ),
      overlayBubble: overlayBubble,
    );

    final state = await requester.request(KoloPermission.overlay);

    expect(overlayBubble.requestPermissionCalls, 1);
    expect(state, PermissionGrantState.granted);
  });

  test(
    'overlay status reports denied when overlay permission was revoked',
    () async {
      final overlayBubble = _FakeOverlayBubbleService(
        requestResult: false,
        permissionGranted: false,
      );
      final requester = AndroidPermissionRequester(
        capabilities: _FakeAndroidCapabilities(
          notificationListenerEnabled: false,
        ),
        overlayBubble: overlayBubble,
      );

      final state = await requester.status(KoloPermission.overlay);

      expect(state, PermissionGrantState.denied);
      expect(overlayBubble.permissionChecks, 1);
      expect(overlayBubble.requestPermissionCalls, 0);
    },
  );

  test('status reads Android listener and accessibility settings', () async {
    final capabilities = _FakeAndroidCapabilities(
      notificationListenerEnabled: true,
      accessibilityServiceEnabled: false,
    );
    final requester = AndroidPermissionRequester(capabilities: capabilities);

    expect(
      await requester.status(KoloPermission.notifications),
      PermissionGrantState.granted,
    );
    expect(
      await requester.status(KoloPermission.accessibility),
      PermissionGrantState.denied,
    );
    expect(capabilities.openedNotificationSettings, isFalse);
    expect(capabilities.openedAccessibilitySettings, isFalse);
  });
}

class _FakeKoloBackgroundServiceController
    extends KoloBackgroundServiceController {
  _FakeKoloBackgroundServiceController() : super(platform: null);

  int configureCalls = 0;
  int startCalls = 0;

  @override
  Future<bool> configure() async {
    configureCalls += 1;
    return true;
  }

  @override
  Future<bool> start() async {
    startCalls += 1;
    return true;
  }
}

class _FakeOverlayBubbleService implements OverlayBubbleService {
  _FakeOverlayBubbleService({
    required this.requestResult,
    this.permissionGranted = true,
  });

  final bool requestResult;
  final bool permissionGranted;
  int permissionChecks = 0;
  int requestPermissionCalls = 0;

  @override
  Future<bool> isPermissionGranted() async {
    permissionChecks += 1;
    return permissionGranted;
  }

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalls += 1;
    return requestResult;
  }

  @override
  Future<bool> showKoloBubble() async => true;

  @override
  Future<bool> showBlockOverlay({
    required String appName,
    required String packageName,
    required WatchedAppBlockLevel blockLevel,
    required String prompt,
  }) async => true;

  @override
  Future<bool?> expandConversation() async => true;

  @override
  Future<bool?> collapseToBubble() async => true;

  @override
  Future<Object?> sendPromptToOverlay(String prompt) async => null;

  @override
  Future<Object?> sendAssistantMessageToOverlay(String message) async => null;

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

class _FakeAndroidCapabilities extends AndroidCapabilityService {
  _FakeAndroidCapabilities({
    required this.notificationListenerEnabled,
    this.accessibilityServiceEnabled = false,
    this.backgroundWatcherStarted = false,
  });

  final bool notificationListenerEnabled;
  final bool accessibilityServiceEnabled;
  final bool backgroundWatcherStarted;
  bool openedNotificationSettings = false;
  bool openedAccessibilitySettings = false;
  bool startedBackgroundWatcher = false;

  @override
  Future<bool> openNotificationListenerSettings() async {
    openedNotificationSettings = true;
    return true;
  }

  @override
  Future<bool> isNotificationListenerEnabled() async {
    return notificationListenerEnabled;
  }

  @override
  Future<bool> openAccessibilitySettings() async {
    openedAccessibilitySettings = true;
    return true;
  }

  @override
  Future<bool> isAccessibilityServiceEnabled() async {
    return accessibilityServiceEnabled;
  }

  @override
  Future<bool> startBackgroundWatcher() async {
    startedBackgroundWatcher = true;
    return backgroundWatcherStarted;
  }
}
