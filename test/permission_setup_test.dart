import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';
import 'package:kolo/domain/services/permission_requester.dart';
import 'package:kolo/domain/services/partner_summary_builder.dart';
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

  testWidgets('permission setup hydrates denied capabilities as locked', (
    tester,
  ) async {
    final repository = _RecordingKoloRepository(
      permissionStates: const {KoloPermission.sms: PermissionGrantState.denied},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [koloRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: KoloTheme.light,
          home: const PermissionSetupScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('permission_locked_sms')), findsOneWidget);
    expect(find.byKey(const Key('permission_granted_sms')), findsNothing);
  });

  testWidgets('permission setup shows locked state after a denial', (
    tester,
  ) async {
    final repository = _RecordingKoloRepository();
    final requester = _RecordingPermissionRequester(
      result: PermissionGrantState.denied,
    );

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

    expect(repository.permission, KoloPermission.sms);
    expect(repository.state, PermissionGrantState.denied);
    expect(find.byKey(const Key('permission_locked_sms')), findsOneWidget);
  });
}

class _RecordingPermissionRequester implements PermissionRequester {
  _RecordingPermissionRequester({this.result = PermissionGrantState.granted});

  final PermissionGrantState result;
  KoloPermission? permission;

  @override
  Future<PermissionGrantState> request(KoloPermission permission) async {
    this.permission = permission;
    return result;
  }
}

class _RecordingKoloRepository implements KoloRepository {
  _RecordingKoloRepository({
    Map<KoloPermission, PermissionGrantState> permissionStates = const {},
  }) : _state = _dashboardState(permissionStates);

  DashboardState _state;
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
  Future<void> deleteVault(String vaultId) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertOwing(Owing owing) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteOwing(String owingId) {
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
  Future<void> deleteBill(String billId) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertPartnerShare(PartnerShare share) {
    throw UnimplementedError();
  }

  @override
  Future<PartnerSafeSummary?> publishPartnerSummary(PartnerShare share) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertWatchedApp(WatchedApp app) {
    throw UnimplementedError();
  }

  @override
  Future<BudgetPlan> completeOnboarding(
    OnboardingAnswers answers, {
    BudgetPlan? budget,
  }) {
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
  Future<void> updateTransactionCategory({
    required String transactionId,
    required String category,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> recordAiMessage(AiMessage message) {
    throw UnimplementedError();
  }

  @override
  Future<void> clearAiMessages() {
    throw UnimplementedError();
  }

  @override
  Future<String> draftOwingReminder(Owing owing) {
    throw UnimplementedError();
  }

  @override
  Future<WeeklyInsight> generateWeeklyInsight() {
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
    _state = _state.copyWith(
      permissions: {..._state.permissions, permission: state},
    );
  }

  @override
  Future<void> updatePreferredAiModel(String modelName) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) {
    throw UnimplementedError();
  }

  @override
  Stream<DashboardState> watchDashboard() {
    return Stream<DashboardState>.value(_state);
  }
}

DashboardState _dashboardState(
  Map<KoloPermission, PermissionGrantState> permissionStates,
) {
  return DashboardState(
    profile: UserProfile(
      uid: 'test-user',
      name: 'Micah',
      email: 'micah@kolo.app',
      createdAt: DateTime(2026, 5, 24),
      onboardingComplete: true,
    ),
    balanceKobo: 0,
    balanceAdjustments: const [],
    budgetPlan: const BudgetPlan(
      monthlyIncomeKobo: 0,
      incomeType: 'irregular',
      categories: [],
      savingsTargetKobo: 0,
      savingsGoal: '',
      aiNotes: '',
    ),
    transactions: const [],
    aiMessages: const [],
    vaults: const [],
    owings: const [],
    gigs: const [],
    bills: const [],
    watchedApps: const [],
    partnerShares: const [],
    insights: const [],
    permissions: permissionStates,
  );
}
