import 'dart:io';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/services/kolo_background_service.dart';

void main() {
  test(
    'background service configures Android foreground data sync mode',
    () async {
      final platform = _FakeKoloBackgroundServicePlatform();
      final controller = KoloBackgroundServiceController(platform: platform);

      final configured = await controller.configure();

      expect(configured, isTrue);
      expect(platform.androidConfiguration, isNotNull);
      expect(platform.androidConfiguration!.isForegroundMode, isTrue);
      expect(platform.androidConfiguration!.autoStart, isFalse);
      expect(platform.androidConfiguration!.autoStartOnBoot, isTrue);
      expect(
        platform.androidConfiguration!.notificationChannelId,
        'kolo_background',
      );
      expect(
        platform.androidConfiguration!.foregroundServiceNotificationId,
        42,
      );
      expect(
        platform.androidConfiguration!.foregroundServiceTypes,
        contains(AndroidForegroundType.dataSync),
      );
      expect(platform.iosConfiguration, isNotNull);
    },
  );

  test(
    'background service starts only when it is not already running',
    () async {
      final platform = _FakeKoloBackgroundServicePlatform(isRunning: false);
      final controller = KoloBackgroundServiceController(platform: platform);

      expect(await controller.start(), isTrue);
      expect(platform.startCalls, 1);

      platform.running = true;
      expect(await controller.start(), isTrue);
      expect(platform.startCalls, 1);
    },
  );

  test('background entrypoint drains native events with Firebase context', () {
    final source = File(
      'lib/data/services/kolo_background_service.dart',
    ).readAsStringSync();

    expect(source, contains('@pragma(\'vm:entry-point\')'));
    expect(source, contains('koloBackgroundServiceEntryPoint'));
    expect(source, contains('DartPluginRegistrant.ensureInitialized'));
    expect(source, contains('FirebaseBootstrap.tryInitialize'));
    expect(source, contains('FirebaseAuth.instance.currentUser'));
    expect(source, contains('NativeEventIngestor('));
    expect(source, contains('Timer.periodic'));
    expect(source, contains('Duration(seconds: 15)'));
    expect(source, isNot(contains('Duration(minutes: 5)')));
    expect(source, contains('service.invoke'));
  });

  test('main configures the background service before launching Kolo', () {
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(mainSource, contains('KoloBackgroundServiceController().configure'));
  });
}

class _FakeKoloBackgroundServicePlatform
    implements KoloBackgroundServicePlatform {
  _FakeKoloBackgroundServicePlatform({bool isRunning = false})
    : running = isRunning;

  AndroidConfiguration? androidConfiguration;
  IosConfiguration? iosConfiguration;
  bool running;
  int startCalls = 0;

  @override
  Future<bool> configure({
    required IosConfiguration iosConfiguration,
    required AndroidConfiguration androidConfiguration,
  }) async {
    this.iosConfiguration = iosConfiguration;
    this.androidConfiguration = androidConfiguration;
    return true;
  }

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<bool> startService() async {
    startCalls += 1;
    running = true;
    return true;
  }
}
