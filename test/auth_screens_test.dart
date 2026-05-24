import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/repositories/auth_repository.dart';
import 'package:kolo/ui/features/auth/auth_screens.dart';

void main() {
  testWidgets('login submits email and password to the auth repository', (
    tester,
  ) async {
    final auth = _RecordingAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.enterText(find.byKey(const Key('auth_email')), 'me@kolo.app');
    await tester.enterText(find.byKey(const Key('auth_password')), 'secret123');
    await tester.tap(find.byKey(const Key('auth_continue')));
    await tester.pump();

    expect(auth.lastSignInEmail, 'me@kolo.app');
    expect(auth.lastSignInPassword, 'secret123');
  });

  testWidgets('signup submits name, email, and password to auth repository', (
    tester,
  ) async {
    final auth = _RecordingAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: SignupScreen()),
      ),
    );

    await tester.enterText(find.byKey(const Key('auth_name')), 'Micah');
    await tester.enterText(find.byKey(const Key('auth_email')), 'me@kolo.app');
    await tester.enterText(find.byKey(const Key('auth_password')), 'secret123');
    await tester.tap(find.byKey(const Key('auth_continue')));
    await tester.pump();

    expect(auth.lastCreateName, 'Micah');
    expect(auth.lastCreateEmail, 'me@kolo.app');
    expect(auth.lastCreatePassword, 'secret123');
  });
}

class _RecordingAuthRepository implements AuthRepository {
  String? lastCreateEmail;
  String? lastCreateName;
  String? lastCreatePassword;
  String? lastSignInEmail;
  String? lastSignInPassword;

  @override
  Future<AuthUser> createUserWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    lastCreateName = name;
    lastCreateEmail = email;
    lastCreatePassword = password;
    return AuthUser(uid: 'created-user', email: email, displayName: name);
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    lastSignInEmail = email;
    lastSignInPassword = password;
    return AuthUser(uid: 'signed-in-user', email: email);
  }

  @override
  Stream<AuthUser?> watchAuthState() {
    return Stream<AuthUser?>.value(null);
  }
}
