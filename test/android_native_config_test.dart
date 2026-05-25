import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android Kotlin classes use the configured app namespace', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final namespace = RegExp(
      r'namespace\s*=\s*"([^"]+)"',
    ).firstMatch(gradle)?.group(1);

    expect(namespace, isNotNull);

    final kotlinFiles = Directory('android/app/src/main/kotlin')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.kt'));

    for (final file in kotlinFiles) {
      final source = file.readAsStringSync();
      final declaredPackage = RegExp(
        r'^package\s+([^\s]+)',
        multiLine: true,
      ).firstMatch(source)?.group(1);

      expect(
        declaredPackage,
        namespace,
        reason: '${file.path} must resolve from AndroidManifest relative names',
      );
    }
  });

  test('Android services enqueue native events for Flutter to drain', () {
    expect(
      File(
        'android/app/src/main/kotlin/com/micah/kolo/KoloNativeEventQueue.kt',
      ).existsSync(),
      isTrue,
    );

    final mainActivity = File(
      'android/app/src/main/kotlin/com/micah/kolo/MainActivity.kt',
    ).readAsStringSync();
    expect(mainActivity, contains('drainNativeEvents'));

    for (final path in [
      'android/app/src/main/kotlin/com/example/kolo/KoloSmsReceiver.kt',
      'android/app/src/main/kotlin/com/example/kolo/KoloNotificationListenerService.kt',
      'android/app/src/main/kotlin/com/example/kolo/KoloAccessibilityService.kt',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('KoloNativeEventQueue.enqueue'),
        reason: '$path must persist events for Flutter',
      );
    }
  });

  test('SMS receiver forwards sender metadata with the message body', () {
    final smsReceiver = File(
      'android/app/src/main/kotlin/com/example/kolo/KoloSmsReceiver.kt',
    ).readAsStringSync();

    expect(smsReceiver, contains('displayOriginatingAddress'));
    expect(smsReceiver, contains('"sender" to sender'));
  });

  test('Android manifest declares notification runtime permission', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
  });

  test('MainActivity exposes notification listener enabled status', () {
    final mainActivity = File(
      'android/app/src/main/kotlin/com/micah/kolo/MainActivity.kt',
    ).readAsStringSync();

    expect(mainActivity, contains('isNotificationListenerEnabled'));
    expect(mainActivity, contains('enabled_notification_listeners'));
  });

  test('MainActivity exposes accessibility service enabled status', () {
    final mainActivity = File(
      'android/app/src/main/kotlin/com/micah/kolo/MainActivity.kt',
    ).readAsStringSync();

    expect(mainActivity, contains('isAccessibilityServiceEnabled'));
    expect(mainActivity, contains('enabled_accessibility_services'));
  });

  test('MainActivity can start the foreground watcher service', () {
    final mainActivity = File(
      'android/app/src/main/kotlin/com/micah/kolo/MainActivity.kt',
    ).readAsStringSync();

    expect(mainActivity, contains('startBackgroundWatcher'));
    expect(mainActivity, contains('KoloForegroundService::class.java'));
    expect(mainActivity, contains('startForegroundService'));
  });

  test('MainActivity suggests every v1 fintech app from the PRD', () {
    final mainActivity = File(
      'android/app/src/main/kotlin/com/micah/kolo/MainActivity.kt',
    ).readAsStringSync();

    const expectedApps = {
      'com.kuda.android': 'Kuda',
      'team.opay.pay': 'Opay',
      'com.palmpay.android': 'Palmpay',
      'com.moniepoint.personal': 'Moniepoint',
      'com.lenddo.mobile.paylater': 'Carbon',
      'ng.com.fairmoney.fairmoney': 'FairMoney',
    };

    for (final entry in expectedApps.entries) {
      expect(mainActivity, contains('"${entry.key}" to "${entry.value}"'));
    }
  });
}
