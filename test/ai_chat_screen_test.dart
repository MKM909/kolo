import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';
import 'package:kolo/domain/services/ai_failure_message.dart';
import 'package:kolo/domain/services/partner_summary_builder.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/features/ai_chat/ai_chat_screen.dart';

void main() {
  testWidgets('AI chat shows a friendly offline state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(
            (ref) => Stream<DashboardState>.error(StateError('offline')),
          ),
        ],
        child: MaterialApp(theme: KoloTheme.light, home: const AiChatScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kolo_ai_offline_state')), findsOneWidget);
    expect(find.text('Kolo is offline'), findsOneWidget);
    expect(find.textContaining('saved chats and balance'), findsOneWidget);
    expect(find.byKey(const Key('kolo_ai_chat_input')), findsNothing);
  });

  testWidgets('AI chat shows friendly feedback when sending fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          koloRepositoryProvider.overrideWithValue(_FailingChatRepository()),
        ],
        child: MaterialApp(
          theme: KoloTheme.light,
          home: const Scaffold(body: AiChatScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('kolo_ai_chat_input')),
      'Can I afford shawarma?',
    );
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text(AiFailureMessage.chat), findsOneWidget);
    expect(find.text('Can I afford shawarma?'), findsOneWidget);
  });

  testWidgets('AI chat previews and accepts a budget replan', (tester) async {
    final repository = _BudgetPreviewRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [koloRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: KoloTheme.light,
          home: const Scaffold(body: AiChatScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Redo my budget, I just got a gig'));
    await tester.pumpAndSettle();

    expect(repository.generatedAnswers?.currentBalanceKobo, 2400000);
    expect(find.byKey(const Key('ai_budget_replan_preview')), findsOneWidget);
    expect(find.text('New budget preview'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai_accept_budget_replan')));
    await tester.pumpAndSettle();

    expect(repository.updatedBudget?.savingsGoal, 'Laptop');
    expect(find.byKey(const Key('ai_budget_replan_preview')), findsNothing);
    expect(find.textContaining('Budget updated'), findsOneWidget);
  });
}

class _FailingChatRepository implements KoloRepository {
  @override
  Stream<DashboardState> watchDashboard() => Stream.value(_dashboardState);

  @override
  Future<AiMessage> sendAiMessage(String message) async {
    throw StateError('Gemini unavailable');
  }

  @override
  Future<void> adjustBalance(BalanceAdjustment adjustment) async {}

  @override
  Future<void> clearAiMessages() async {}

  @override
  Future<BudgetPlan> completeOnboarding(
    OnboardingAnswers answers, {
    BudgetPlan? budget,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> draftOwingReminder(Owing owing) async {
    throw UnimplementedError();
  }

  @override
  Future<WeeklyInsight> generateWeeklyInsight() async {
    throw UnimplementedError();
  }

  @override
  Future<BudgetPlan> generateBudget(OnboardingAnswers answers) async {
    throw UnimplementedError();
  }

  @override
  Future<void> logTransaction(TransactionRecord transaction) async {}

  @override
  Future<void> updateTransactionCategory({
    required String transactionId,
    required String category,
  }) async {}

  @override
  Future<PartnerSafeSummary?> publishPartnerSummary(PartnerShare share) async {
    return null;
  }

  @override
  Future<void> recordAiMessage(AiMessage message) async {}

  @override
  Future<void> updateBudget(BudgetPlan budget) async {}

  @override
  Future<void> updatePermission(
    KoloPermission permission,
    PermissionGrantState state,
  ) async {}

  @override
  Future<void> updatePreferredAiModel(String modelName) async {}

  @override
  Future<void> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) async {}

  @override
  Future<void> upsertBill(BillReminder bill) async {}

  @override
  Future<void> deleteBill(String billId) async {}

  @override
  Future<void> upsertGig(GigRecord gig) async {}

  @override
  Future<void> upsertOwing(Owing owing) async {}

  @override
  Future<void> deleteOwing(String owingId) async {}

  @override
  Future<void> upsertPartnerShare(PartnerShare share) async {}

  @override
  Future<void> upsertVault(SavingsVault vault) async {}

  @override
  Future<void> deleteVault(String vaultId) async {}

  @override
  Future<void> upsertWatchedApp(WatchedApp app) async {}
}

class _BudgetPreviewRepository extends _FailingChatRepository {
  OnboardingAnswers? generatedAnswers;
  BudgetPlan? updatedBudget;
  var _state = _dashboardState;

  @override
  Stream<DashboardState> watchDashboard() => Stream.value(_state);

  @override
  Future<BudgetPlan> generateBudget(OnboardingAnswers answers) async {
    generatedAnswers = answers;
    return const BudgetPlan(
      monthlyIncomeKobo: 7000000,
      incomeType: 'irregular',
      categories: [
        BudgetCategory(
          name: 'Transport',
          emoji: '*',
          allocatedKobo: 1200000,
          priority: 1,
        ),
        BudgetCategory(
          name: 'Food & Snacks',
          emoji: '*',
          allocatedKobo: 900000,
          priority: 2,
        ),
      ],
      savingsTargetKobo: 1000000,
      savingsGoal: 'Laptop',
      aiNotes: 'I tightened snacks and protected gig income.',
    );
  }

  @override
  Future<void> updateBudget(BudgetPlan budget) async {
    updatedBudget = budget;
    _state = _state.copyWith(budgetPlan: budget);
  }

  @override
  Future<AiMessage> sendAiMessage(String message) async {
    return AiMessage(
      id: 'ai-replan-chat',
      role: AiRole.assistant,
      content: 'I can rework that budget.',
      timestamp: DateTime(2026, 5, 25),
      context: 'chat',
    );
  }
}

final _dashboardState = DashboardState(
  profile: UserProfile(
    uid: 'demo-user',
    name: 'Demo User',
    email: 'demo@kolo.app',
    createdAt: DateTime(2026, 5, 24),
    onboardingComplete: true,
  ),
  balanceKobo: 2400000,
  balanceAdjustments: const [],
  budgetPlan: const BudgetPlan(
    monthlyIncomeKobo: 5000000,
    incomeType: 'irregular',
    categories: [
      BudgetCategory(
        name: 'Food & Snacks',
        emoji: '*',
        allocatedKobo: 1000000,
        priority: 1,
      ),
    ],
    savingsTargetKobo: 500000,
    savingsGoal: 'Emergency buffer',
    aiNotes: 'Keep snacks controlled.',
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
  permissions: const {},
);
