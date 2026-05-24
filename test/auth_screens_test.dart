import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/data/services/biometric_unlock_service.dart';
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
    expect(auth.verificationEmailSends, 1);
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

  testWidgets('login can unlock with biometrics', (tester) async {
    final biometric = _RecordingBiometricUnlockService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          biometricUnlockServiceProvider.overrideWithValue(biometric),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.byKey(const Key('auth_biometric_unlock')));
    await tester.pump();

    expect(biometric.unlockCalls, 1);
  });

  testWidgets('email verification screen can resend and check status', (
    tester,
  ) async {
    final auth = _RecordingAuthRepository(
      reloadedUser: const AuthUser(
        uid: 'created-user',
        email: 'me@kolo.app',
        emailVerified: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: EmailVerificationScreen()),
      ),
    );

    await tester.tap(find.byKey(const Key('resend_verification_email')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('check_email_verification')));
    await tester.pump();

    expect(auth.verificationEmailSends, 1);
    expect(auth.reloadCurrentUserCalls, 1);
    expect(find.text('Still waiting for verification.'), findsOneWidget);
  });
}

class _RecordingBiometricUnlockService implements BiometricUnlockService {
  int unlockCalls = 0;

  @override
  Future<bool> unlock() async {
    unlockCalls += 1;
    return true;
  }
}

class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({this.reloadedUser});

  String? lastCreateEmail;
  String? lastCreateName;
  String? lastCreatePassword;
  String? lastSignInEmail;
  String? lastSignInPassword;
  int googleSignInCalls = 0;
  int verificationEmailSends = 0;
  int reloadCurrentUserCalls = 0;
  final AuthUser? reloadedUser;

  @override
  Future<AuthUser> createUserWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    lastCreateName = name;
    lastCreateEmail = email;
    lastCreatePassword = password;
    return AuthUser(
      uid: 'created-user',
      email: email,
      displayName: name,
      emailVerified: false,
    );
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendEmailVerification() async {
    verificationEmailSends += 1;
  }

  @override
  Future<AuthUser?> reloadCurrentUser() async {
    reloadCurrentUserCalls += 1;
    return reloadedUser;
  }

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
