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
}

Future<void> _pumpWithRouter(
  WidgetTester tester, {
  required bool firebaseInitialized,
  required bool authKnown,
  required bool signedIn,
}) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: buildKoloRouter(
          firebaseInitialized: firebaseInitialized,
          authKnown: authKnown,
          signedIn: signedIn,
        ),
      ),
    ),
  );
}
