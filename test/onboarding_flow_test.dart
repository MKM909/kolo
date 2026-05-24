import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/features/auth/auth_screens.dart';

void main() {
  testWidgets('onboarding submits answers and advances to permissions', (
    tester,
  ) async {
    final repository = _RecordingKoloRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [koloRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(
          theme: KoloTheme.light,
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const OnboardingScreen(),
              ),
              GoRoute(
                path: '/permissions',
                builder: (context, state) => const Text('Permissions reached'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('onboarding_income_source')),
      'Freelance design',
    );
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('onboarding_income_frequency_irregular_gigs')),
    );
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('onboarding_balance')),
      '42000',
    );
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding_problem_impulse_buys')));
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();

    expect(repository.answers?.incomeSource, 'Freelance design');
    expect(repository.answers?.incomeFrequency, 'Irregular gigs');
    expect(repository.answers?.currentBalanceKobo, 4200000);
    expect(repository.answers?.biggestProblem, 'Impulse buys');
    expect(find.text('Permissions reached'), findsOneWidget);
  });
}

class _RecordingKoloRepository implements KoloRepository {
  OnboardingAnswers? answers;

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
  Future<BudgetPlan> completeOnboarding(OnboardingAnswers answers) async {
    this.answers = answers;
    return const BudgetPlan(
      monthlyIncomeKobo: 8400000,
      incomeType: 'irregular',
      categories: [
        BudgetCategory(
          name: 'Food & Snacks',
          emoji: 'food',
          allocatedKobo: 1200000,
          priority: 1,
        ),
      ],
      savingsTargetKobo: 1000000,
      savingsGoal: 'Emergency buffer',
      aiNotes: 'Test budget',
    );
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
  Future<void> recordAiMessage(AiMessage message) {
    throw UnimplementedError();
  }

  @override
  Future<String> draftOwingReminder(Owing owing) {
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
  ) {
    throw UnimplementedError();
  }

  @override
  Stream<DashboardState> watchDashboard() {
    throw UnimplementedError();
  }
}
