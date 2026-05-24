import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/router.dart';

void main() {
  testWidgets('Firebase launch redirects signed-out users to login', (
    tester,
  ) async {
    await _pumpWithRouter(
      tester,
      firebaseInitialized: true,
      authKnown: true,
      signedIn: false,
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('auth_email')), findsOneWidget);
  });

  testWidgets('demo launch keeps the home dashboard available', (tester) async {
    await _pumpWithRouter(
      tester,
      firebaseInitialized: false,
      authKnown: true,
      signedIn: false,
    );

    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('signed-in users with incomplete onboarding open onboarding', (
    tester,
  ) async {
    await _pumpWithRouter(
      tester,
      firebaseInitialized: true,
      authKnown: true,
      signedIn: true,
      onboardingComplete: false,
    );

    await tester.pumpAndSettle();

    expect(find.text('Meet Kolo'), findsOneWidget);
    expect(find.textContaining("I'm Kolo"), findsOneWidget);
  });

  testWidgets('signed-in users with unverified email open verification', (
    tester,
  ) async {
    await _pumpWithRouter(
      tester,
      firebaseInitialized: true,
      authKnown: true,
      signedIn: true,
      emailVerified: false,
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('email_verification_screen')), findsOneWidget);
    expect(find.text('Verify your email'), findsOneWidget);
  });

  testWidgets('signed-in users with a locked session open biometric lock', (
    tester,
  ) async {
    await _pumpWithRouter(
      tester,
      firebaseInitialized: true,
      authKnown: true,
      signedIn: true,
      requiresBiometricUnlock: true,
    );

    await tester.pumpAndSettle();

    expect(find.text('Unlock Kolo'), findsOneWidget);
    expect(find.byKey(const Key('biometric_lock_unlock')), findsOneWidget);
  });
}

Future<void> _pumpWithRouter(
  WidgetTester tester, {
  required bool firebaseInitialized,
  required bool authKnown,
  required bool signedIn,
  bool onboardingComplete = true,
  bool emailVerified = true,
  bool requiresBiometricUnlock = false,
}) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: buildKoloRouter(
          firebaseInitialized: firebaseInitialized,
          authKnown: authKnown,
          signedIn: signedIn,
          onboardingComplete: onboardingComplete,
          emailVerified: emailVerified,
          requiresBiometricUnlock: requiresBiometricUnlock,
        ),
      ),
    ),
  );
}
