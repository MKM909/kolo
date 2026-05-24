import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/kolo_app.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/features/auth/auth_screens.dart';

void main() {
  testWidgets('bottom navigation uses the raised Kolo AI bubble from design spec', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    final bubbleFinder = find.byKey(const Key('kolo_ai_nav_bubble'));
    expect(bubbleFinder, findsOneWidget);

    final bubble = tester.widget<Container>(bubbleFinder);
    final decoration = bubble.decoration as BoxDecoration;
    expect(decoration.color, KoloColors.primary);
    expect(decoration.shape, BoxShape.circle);
  });

  testWidgets('onboarding starts as chat-style setup with progress dots', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: KoloTheme.light, home: const OnboardingScreen()),
    );

    expect(find.byKey(const Key('onboarding_progress_dot_0')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_kolo_bubble')), findsOneWidget);
    expect(find.text('Income source'), findsOneWidget);
    expect(find.byKey(const Key('onboarding_next')), findsOneWidget);
  });

  testWidgets('permission setup lists every v1 Android capability', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: KoloTheme.light, home: const PermissionSetupScreen()),
    );

    for (final key in [
      'permission_sms',
      'permission_notifications',
      'permission_overlay',
      'permission_accessibility',
      'permission_backgroundService',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
  });
}
