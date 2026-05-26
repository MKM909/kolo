import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:kolo/data/repositories/firebase_kolo_repository.dart';
import 'package:kolo/data/services/android_capability_service.dart';
import 'package:kolo/data/services/cloud_ai_service.dart';
import 'package:kolo/data/services/firebase_bootstrap.dart';
import 'package:kolo/data/services/native_event_ingestor.dart';
import 'package:kolo/data/services/overlay_bubble_service.dart';

abstract class KoloBackgroundServicePlatform {
  Future<bool> configure({
    required IosConfiguration iosConfiguration,
    required AndroidConfiguration androidConfiguration,
  });

  Future<bool> startService();

  Future<bool> isRunning();
}

class FlutterKoloBackgroundServicePlatform
    implements KoloBackgroundServicePlatform {
  FlutterKoloBackgroundServicePlatform({FlutterBackgroundService? service})
    : _service = service ?? FlutterBackgroundService();

  final FlutterBackgroundService _service;

  @override
  Future<bool> configure({
    required IosConfiguration iosConfiguration,
    required AndroidConfiguration androidConfiguration,
  }) {
    return _service.configure(
      iosConfiguration: iosConfiguration,
      androidConfiguration: androidConfiguration,
    );
  }

  @override
  Future<bool> isRunning() {
    return _service.isRunning();
  }

  @override
  Future<bool> startService() {
    return _service.startService();
  }
}

class KoloBackgroundServiceController {
  KoloBackgroundServiceController({KoloBackgroundServicePlatform? platform})
    : _platform = platform ?? FlutterKoloBackgroundServicePlatform();

  final KoloBackgroundServicePlatform _platform;

  Future<bool> configure() async {
    try {
      return await _platform.configure(
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: koloBackgroundServiceEntryPoint,
          onBackground: koloIosBackgroundServiceEntryPoint,
        ),
        androidConfiguration: AndroidConfiguration(
          onStart: koloBackgroundServiceEntryPoint,
          autoStart: false,
          autoStartOnBoot: true,
          isForegroundMode: true,
          notificationChannelId: 'kolo_background',
          initialNotificationTitle: 'Kolo is watching your spending context',
          initialNotificationContent:
              'Transaction alerts and watched apps can trigger Kolo.',
          foregroundServiceNotificationId: 42,
          foregroundServiceTypes: const [AndroidForegroundType.dataSync],
        ),
      );
    } on Object {
      return false;
    }
  }

  Future<bool> start() async {
    try {
      if (await _platform.isRunning()) return true;
      return await _platform.startService();
    } on Object {
      return false;
    }
  }
}

@pragma('vm:entry-point')
Future<void> koloBackgroundServiceEntryPoint(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  service.on('stopService').listen((_) {
    service.stopSelf();
  });

  await drainKoloNativeEventsInBackground(service);
  Timer.periodic(const Duration(minutes: 5), (_) {
    drainKoloNativeEventsInBackground(service);
  });
}

@pragma('vm:entry-point')
Future<bool> koloIosBackgroundServiceEntryPoint(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  await drainKoloNativeEventsInBackground(service);
  return true;
}

Future<int> drainKoloNativeEventsInBackground(ServiceInstance service) async {
  try {
    final bootstrap = await FirebaseBootstrap.tryInitialize();
    if (!bootstrap.initialized) {
      service.invoke('koloStatus', {'state': 'firebase_unavailable'});
      return 0;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      service.invoke('koloStatus', {'state': 'signed_out'});
      return 0;
    }

    final aiService = CloudAiService();
    final ingestor = NativeEventIngestor(
      capabilities: AndroidCapabilityService(),
      repository: FirebaseKoloRepository(uid: user.uid),
      overlayBubble: OverlayBubbleService(),
      categorizer: aiService,
      interventionAdvisor: aiService,
      smsReceivedHandler: aiService,
    );
    final processed = await ingestor.drainAndProcess();
    service.invoke('koloDrain', {
      'processed': processed,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    return processed;
  } on Object {
    service.invoke('koloStatus', {'state': 'error'});
    return 0;
  }
}
