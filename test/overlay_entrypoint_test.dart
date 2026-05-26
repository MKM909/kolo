import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/main.dart';

void main() {
  test('main.dart defines the flutter_overlay_window entrypoint', () {
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(mainSource, contains('@pragma("vm:entry-point")'));
    expect(mainSource, contains('void overlayMain()'));
    expect(mainSource, contains('KoloOverlayBubble'));
    expect(mainSource, contains('KoloLiquidAetherOrb'));
    expect(mainSource, contains('FlutterOverlayWindow.resizeOverlay'));
    expect(mainSource, contains('FlutterOverlayWindow.shareData'));
    expect(mainSource, contains('FlutterOverlayWindow.overlayListener'));
  });

  testWidgets('overlay bubble expands into a conversational panel', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: KoloOverlayBubble()));

    expect(find.byKey(const Key('kolo_overlay_idle')), findsOneWidget);
    expect(find.byKey(const Key('kolo_overlay_speech_bubble')), findsOneWidget);

    await tester.tap(find.byKey(const Key('kolo_overlay_orb')));
    await tester.pump();

    expect(find.byKey(const Key('kolo_overlay_conversation')), findsOneWidget);
    expect(find.text('Kolo'), findsOneWidget);
    expect(find.byKey(const Key('kolo_overlay_input')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('kolo_overlay_input')),
      'Can I spend 5000 on food?',
    );
    await tester.tap(find.byKey(const Key('kolo_overlay_send')));
    await tester.pump();

    expect(find.text('Can I spend 5000 on food?'), findsOneWidget);
    expect(find.textContaining('I can help you pressure-test'), findsOneWidget);
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
