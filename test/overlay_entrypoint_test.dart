import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main.dart defines the flutter_overlay_window entrypoint', () {
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(mainSource, contains('@pragma("vm:entry-point")'));
    expect(mainSource, contains('void overlayMain()'));
    expect(mainSource, contains('KoloOverlayBubble'));
    expect(mainSource, contains('KoloLiquidAetherOrb'));
  });

  test('Android manifest registers the overlay plugin service', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('flutter.overlay.window.flutter_overlay_window.OverlayService'),
    );
    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_SPECIAL_USE'),
    );
    expect(manifest, contains('android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE'));
  });
}
