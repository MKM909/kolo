import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/data/repositories/fake_kolo_repository.dart';
import 'package:kolo/domain/repositories/auth_repository.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/features/profile/profile_screen.dart';

void main() {
  testWidgets('profile sign out calls the auth repository', (tester) async {
    final auth = _SignOutAuthRepository();
    final repository = FakeKoloRepository.seeded();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          koloRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(theme: KoloTheme.light, home: const ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i += 1) {
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('profile_sign_out')));
    await tester.pump();

    expect(auth.signedOut, isTrue);
    expect(find.text('Signed out of Kolo.'), findsOneWidget);
  });
}

class _SignOutAuthRepository implements AuthRepository {
  bool signedOut = false;

  @override
  Future<AuthUser> createUserWithEmail({
    required String name,
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser?> reloadCurrentUser() {
    throw UnimplementedError();
  }

  @override
  Future<void> sendEmailVerification() {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> signInWithGoogle() {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  Stream<AuthUser?> watchAuthState() {
    return Stream<AuthUser?>.value(
      const AuthUser(uid: 'demo-user', email: 'demo@kolo.app'),
    );
  }
}
