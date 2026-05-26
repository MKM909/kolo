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

  test('Android Gradle config is no longer the stock Flutter template', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('applicationId = "com.micah.kolo"'));
    expect(gradle, isNot(contains('TODO:')));
    expect(gradle, contains('com.google.firebase:firebase-bom'));
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
    expect(mainActivity, contains('peekNativeEvents'));
    expect(mainActivity, contains('enqueueNativeEvent'));

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
    expect(manifest, contains('android.permission.SCHEDULE_EXACT_ALARM'));
    expect(manifest, contains('.KoloReminderReceiver'));
  });

  test(
    'Android reminder receiver queues reminder events for Dart processing',
    () {
      final receiver = File(
        'android/app/src/main/kotlin/com/micah/kolo/KoloReminderReceiver.kt',
      ).readAsStringSync();

      expect(receiver, contains('KoloNativeEventQueue.enqueue'));
      expect(receiver, contains('"reminder"'));
      expect(receiver, contains('"kind" to'));
      expect(receiver, contains('JSONObject(payload)'));
    },
  );

  test('Android boot receiver queues boot events for Dart processing', () {
    final receiver = File(
      'android/app/src/main/kotlin/com/example/kolo/KoloBootReceiver.kt',
    ).readAsStringSync();

    expect(receiver, contains('KoloNativeEventQueue.enqueue'));
    expect(receiver, contains('"boot_completed"'));
    expect(receiver, contains('"action" to intent.action'));
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

  test('Android block cancel can perform accessibility global back', () {
    final mainActivity = File(
      'android/app/src/main/kotlin/com/micah/kolo/MainActivity.kt',
    ).readAsStringSync();
    final accessibilityService = File(
      'android/app/src/main/kotlin/com/example/kolo/KoloAccessibilityService.kt',
    ).readAsStringSync();

    expect(mainActivity, contains('performGlobalBack'));
    expect(
      mainActivity,
      contains('KoloAccessibilityService.performGlobalBackAction()'),
    );
    expect(accessibilityService, contains('performGlobalBackAction'));
    expect(
      accessibilityService,
      contains('performGlobalAction(GLOBAL_ACTION_BACK)'),
    );
  });

  test('foreground watcher notification taps open Kolo AI', () {
    final foregroundService = File(
      'android/app/src/main/kotlin/com/example/kolo/KoloForegroundService.kt',
    ).readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(foregroundService, contains('PendingIntent.getActivity'));
    expect(foregroundService, contains('Intent.ACTION_VIEW'));
    expect(foregroundService, contains('Uri.parse("kolo://app/ai?prompt='));
    expect(foregroundService, contains('.setContentIntent('));
    expect(manifest, contains('android.intent.category.BROWSABLE'));
    expect(manifest, contains('android:scheme="kolo"'));
    expect(manifest, contains('android:host="app"'));
  });

  test('Android launch branding uses Kolo label adaptive icon and splash', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final launchBackground = File(
      'android/app/src/main/res/drawable/launch_background.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:label="@string/app_name"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
    expect(
      File('android/app/src/main/res/values/colors.xml').existsSync(),
      isTrue,
    );
    expect(
      File(
        'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      ).existsSync(),
      isTrue,
    );
    expect(launchBackground, contains('@color/kolo_splash_start'));
    expect(launchBackground, contains('@drawable/ic_launcher_foreground'));
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

  test(
    'MainActivity discovers installed launcher apps for watched app picker',
    () {
      final mainActivity = File(
        'android/app/src/main/kotlin/com/micah/kolo/MainActivity.kt',
      ).readAsStringSync();

      expect(mainActivity, contains('getInstalledAppCandidates'));
      expect(mainActivity, contains('Intent.ACTION_MAIN'));
      expect(mainActivity, contains('Intent.CATEGORY_LAUNCHER'));
      expect(mainActivity, contains('queryIntentActivities'));
      expect(mainActivity, contains('isKnownFinancialApp'));
    },
  );
}
