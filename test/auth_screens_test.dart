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

  testWidgets('login can start Google sign-in', (tester) async {
    final auth = _RecordingAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.byKey(const Key('auth_google_sign_in')));
    await tester.pump();

    expect(auth.googleSignInCalls, 1);
  });
}

class _RecordingAuthRepository implements AuthRepository {
  String? lastCreateEmail;
  String? lastCreateName;
  String? lastCreatePassword;
  String? lastSignInEmail;
  String? lastSignInPassword;
  int googleSignInCalls = 0;

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
  Future<AuthUser> signInWithGoogle() async {
    googleSignInCalls += 1;
    return const AuthUser(
      uid: 'google-user',
      email: 'google@kolo.app',
      displayName: 'Google User',
    );
  }

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
