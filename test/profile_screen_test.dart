import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/kolo_app.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/data/repositories/fake_kolo_repository.dart';
import 'package:kolo/data/services/offline_sync_queue.dart';
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

  testWidgets('profile surfaces pending offline sync work', (tester) async {
    final repository = FakeKoloRepository.seeded();
    final pendingOperations = [
      PendingSyncOperation(
        id: 'sync-transaction',
        kind: 'transaction',
        payload: const {'amountKobo': 125000},
        createdAt: DateTime(2026, 5, 24, 8),
      ),
      PendingSyncOperation(
        id: 'sync-bill',
        kind: 'bill',
        payload: const {'billId': 'rent'},
        createdAt: DateTime(2026, 5, 24, 9),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          koloRepositoryProvider.overrideWithValue(repository),
          pendingSyncOperationsProvider.overrideWithValue(
            AsyncData(pendingOperations),
          ),
        ],
        child: MaterialApp(theme: KoloTheme.light, home: const ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile_sync_status')), findsOneWidget);
    expect(find.text('Waiting to sync'), findsOneWidget);
    expect(find.text('2 pending'), findsOneWidget);
  });

  testWidgets('profile notification preferences toggle weekly insights', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('open_notification_preferences')),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(const Key('open_notification_preferences')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('notification_preferences_sheet')),
      findsOneWidget,
    );
    final initial = tester.widget<SwitchListTile>(
      find.byKey(const Key('toggle_preference_weeklyInsights')),
    );
    expect(initial.value, isTrue);

    await tester.tap(find.byKey(const Key('toggle_preference_weeklyInsights')));
    await tester.pumpAndSettle();

    final updated = tester.widget<SwitchListTile>(
      find.byKey(const Key('toggle_preference_weeklyInsights')),
    );
    expect(updated.value, isFalse);
    expect(find.text('Weekly insights'), findsWidgets);
    expect(find.text('Off'), findsWidgets);
  });

  testWidgets('profile budget settings opens the budget screen', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('open_budget_settings')),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(const Key('open_budget_settings')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('budget_period_label')), findsOneWidget);
    expect(find.text('Budget'), findsWidgets);
  });

  testWidgets('profile balance adjustment updates the dashboard balance', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('open_profile_balance_adjustment')),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(const Key('open_profile_balance_adjustment')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('balance_adjustment_sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('balance_adjustment_amount')),
      '70000',
    );
    await tester.tap(find.byKey(const Key('save_balance_adjustment')));
    await tester.pumpAndSettle();

    expect(find.text('₦70,000.00'), findsOneWidget);
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
