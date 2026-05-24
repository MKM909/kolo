import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';
import 'package:kolo/domain/services/permission_requester.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/features/auth/auth_screens.dart';

void main() {
  testWidgets(
    'permission setup grants selected capability through repository',
    (tester) async {
      final repository = _RecordingKoloRepository();
      final requester = _RecordingPermissionRequester();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            koloRepositoryProvider.overrideWithValue(repository),
            permissionRequesterProvider.overrideWithValue(requester),
          ],
          child: MaterialApp(
            theme: KoloTheme.light,
            home: const PermissionSetupScreen(),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('permission_setup_sms')));
      await tester.pumpAndSettle();

      expect(requester.permission, KoloPermission.sms);
      expect(repository.permission, KoloPermission.sms);
      expect(repository.state, PermissionGrantState.granted);
      expect(find.byKey(const Key('permission_granted_sms')), findsOneWidget);
    },
  );
}

class _RecordingPermissionRequester implements PermissionRequester {
  KoloPermission? permission;

  @override
  Future<PermissionGrantState> request(KoloPermission permission) async {
    this.permission = permission;
    return PermissionGrantState.granted;
  }
}

class _RecordingKoloRepository implements KoloRepository {
  KoloPermission? permission;
  PermissionGrantState? state;

  @override
  Future<void> adjustBalance(BalanceAdjustment adjustment) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertVault(SavingsVault vault) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertOwing(Owing owing) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertGig(GigRecord gig) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertBill(BillReminder bill) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertPartnerShare(PartnerShare share) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertWatchedApp(WatchedApp app) {
    throw UnimplementedError();
  }

  @override
  Future<BudgetPlan> completeOnboarding(OnboardingAnswers answers) {
    throw UnimplementedError();
  }

  @override
  Future<BudgetPlan> generateBudget(OnboardingAnswers answers) {
    throw UnimplementedError();
  }

  @override
  Future<void> logTransaction(TransactionRecord transaction) {
    throw UnimplementedError();
  }

  @override
  Future<AiMessage> sendAiMessage(String message) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateBudget(BudgetPlan budget) {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePermission(
    KoloPermission permission,
    PermissionGrantState state,
  ) async {
    this.permission = permission;
    this.state = state;
  }

  @override
  Stream<DashboardState> watchDashboard() {
    throw UnimplementedError();
  }
}
