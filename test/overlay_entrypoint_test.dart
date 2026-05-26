import 'dart:io';
import 'dart:async';

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
    expect(mainSource, contains('overlayListener'));
    expect(mainSource, contains('asBroadcastStream'));
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
    expect(find.text('Kolo is thinking...'), findsOneWidget);
    expect(find.textContaining('I can help you pressure-test'), findsNothing);
  });

  testWidgets('overlay shows bridge assistant replies without duplicates', (
    tester,
  ) async {
    final controller = StreamController<Object?>.broadcast();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(home: KoloOverlayBubble(overlayMessages: controller.stream)),
    );

    await tester.tap(find.byKey(const Key('kolo_overlay_orb')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('kolo_overlay_input')),
      'Can I spend 5000 on food?',
    );
    await tester.tap(find.byKey(const Key('kolo_overlay_send')));
    await tester.pump();

    controller
      ..add({
        'type': 'assistantMessage',
        'text': 'That food spend fits if you keep dinner simple.',
      })
      ..add({
        'type': 'assistantMessage',
        'text': 'That food spend fits if you keep dinner simple.',
      });
    await tester.pump();

    expect(find.text('Kolo is thinking...'), findsNothing);
    expect(
      find.text('That food spend fits if you keep dinner simple.'),
      findsOneWidget,
    );
  });

  testWidgets('overlay quick actions can start category correction', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: KoloOverlayBubble()));

    await tester.tap(find.byKey(const Key('kolo_overlay_orb')));
    await tester.pump();

    expect(
      find.byKey(const Key('kolo_overlay_wrong_category')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('kolo_overlay_wrong_category')));
    await tester.pump();

    final input = tester.widget<TextField>(
      find.byKey(const Key('kolo_overlay_input')),
    );
    expect(input.controller?.text, "That's wrong category, it should be ");
  });

  testWidgets('overlay renders block mode with aether background and chat', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: KoloOverlayBubble(
          initialOverlayData: {
            'type': 'blockOverlay',
            'appName': 'Kuda',
            'packageName': 'com.kuda.android',
            'blockLevel': 'hardLock',
            'prompt': 'Hold on. You just opened Kuda. What is the plan?',
          },
        ),
      ),
    );

    expect(find.byKey(const Key('kolo_block_overlay')), findsOneWidget);
    expect(find.byKey(const Key('kolo_aether_background')), findsOneWidget);
    expect(find.byKey(const Key('kolo_block_orb')), findsOneWidget);
    expect(find.text('Kolo'), findsOneWidget);
    expect(find.text('Hard Lock'), findsOneWidget);
    expect(find.textContaining('opening Kuda'), findsOneWidget);
    expect(find.textContaining('What is the plan?'), findsOneWidget);
    expect(find.byKey(const Key('kolo_block_input')), findsOneWidget);
    expect(find.byKey(const Key('kolo_block_cancel')), findsOneWidget);
  });

  testWidgets('block overlay reacts to caution decisions with proceed action', (
    tester,
  ) async {
    final controller = StreamController<Object?>.broadcast();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: KoloOverlayBubble(
          overlayMessages: controller.stream,
          initialOverlayData: const {
            'type': 'blockOverlay',
            'appName': 'Kuda',
            'packageName': 'com.kuda.android',
            'blockLevel': 'hardLock',
            'prompt': 'Hold on. You just opened Kuda. What is the plan?',
          },
        ),
      ),
    );

    controller.add({
      'type': 'blockDecision',
      'status': 'caution',
      'message': 'This is risky, but you can override.',
      'appName': 'Kuda',
      'packageName': 'com.kuda.android',
      'blockLevel': 'hardLock',
    });
    await tester.pump();

    expect(find.text('This is risky, but you can override.'), findsOneWidget);
    expect(find.byKey(const Key('kolo_block_proceed_anyway')), findsOneWidget);
    expect(find.byKey(const Key('kolo_block_cancel')), findsOneWidget);
  });

  testWidgets('advised against decisions require typed override confirmation', (
    tester,
  ) async {
    final controller = StreamController<Object?>.broadcast();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: KoloOverlayBubble(
          overlayMessages: controller.stream,
          initialOverlayData: const {
            'type': 'blockOverlay',
            'appName': 'Kuda',
            'packageName': 'com.kuda.android',
            'blockLevel': 'hardLock',
            'prompt': 'Hold on. You just opened Kuda. What is the plan?',
          },
        ),
      ),
    );

    controller.add({
      'type': 'blockDecision',
      'status': 'advisedAgainst',
      'message': 'I would not open Kuda right now.',
      'appName': 'Kuda',
      'packageName': 'com.kuda.android',
      'blockLevel': 'hardLock',
    });
    await tester.pump();

    expect(find.text('I would not open Kuda right now.'), findsOneWidget);
    expect(
      find.text('Type "I understand, let me in" to override.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('kolo_block_override_confirmation')),
      findsOneWidget,
    );

    var overrideButton = tester.widget<FilledButton>(
      find.byKey(const Key('kolo_block_confirm_override')),
    );
    expect(overrideButton.onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('kolo_block_override_confirmation')),
      'I understand, let me in',
    );
    await tester.pump();

    overrideButton = tester.widget<FilledButton>(
      find.byKey(const Key('kolo_block_confirm_override')),
    );
    expect(overrideButton.onPressed, isNotNull);
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
