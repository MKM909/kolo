import 'dart:async';

import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';
import 'package:kolo/domain/services/ai_model_config.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/domain/services/partner_summary_builder.dart';

class FakeKoloRepository implements KoloRepository {
  FakeKoloRepository._(this._state);

  factory FakeKoloRepository.seeded() {
    final now = DateTime(2026, 5, 24, 9, 30);
    return FakeKoloRepository._(
      DashboardState(
        profile: UserProfile(
          uid: 'demo-user',
          name: 'Kolo User',
          email: 'demo@kolo.app',
          createdAt: now.subtract(const Duration(days: 12)),
          onboardingComplete: true,
        ),
        balanceKobo: 5080000,
        balanceAdjustments: const [],
        budgetPlan: const BudgetPlan(
          monthlyIncomeKobo: 12000000,
          incomeType: 'irregular',
          savingsTargetKobo: 2500000,
          savingsGoal: 'New phone',
          aiNotes: 'Keep food controlled and protect vault money first.',
          categories: [
            BudgetCategory(
              name: 'Food & Snacks',
              emoji: '🍜',
              allocatedKobo: 3000000,
              priority: 1,
            ),
            BudgetCategory(
              name: 'Transport',
              emoji: '🚌',
              allocatedKobo: 1500000,
              priority: 2,
            ),
            BudgetCategory(
              name: 'Data & Airtime',
              emoji: '📶',
              allocatedKobo: 1000000,
              priority: 3,
            ),
            BudgetCategory(
              name: 'Entertainment',
              emoji: '🎧',
              allocatedKobo: 1000000,
              priority: 4,
            ),
          ],
        ),
        transactions: [
          TransactionRecord.income(
            id: 'tx-gig',
            amountKobo: 4500000,
            category: 'Gig Income',
            description: 'Landing page gig',
            date: now.subtract(const Duration(days: 2)),
            source: TransactionSource.manual,
            merchantName: 'Teniola Studio',
          ),
          TransactionRecord.expense(
            id: 'tx-food',
            amountKobo: 1250000,
            category: 'Food & Snacks',
            description: 'Chicken Republic',
            date: now.subtract(const Duration(hours: 8)),
            source: TransactionSource.sms,
            merchantName: 'Chicken Republic',
            aiApproved: false,
            aiNote: 'Caution: food budget is climbing quickly.',
          ),
          TransactionRecord.expense(
            id: 'tx-data',
            amountKobo: 500000,
            category: 'Data & Airtime',
            description: 'MTN data bundle',
            date: now.subtract(const Duration(days: 1)),
            source: TransactionSource.notification,
            merchantName: 'MTN',
          ),
        ],
        aiMessages: [
          AiMessage(
            id: 'ai-welcome',
            role: AiRole.assistant,
            content:
                'Your balance is ₦50,800. You have ₦17,500 left in flexible spending and your phone vault is safe.',
            timestamp: now.subtract(const Duration(minutes: 20)),
            context: 'home',
          ),
        ],
        vaults: const [
          SavingsVault(
            id: 'vault-phone',
            name: 'New Phone',
            targetKobo: 18000000,
            currentKobo: 4600000,
          ),
          SavingsVault(
            id: 'vault-emergency',
            name: 'Emergency',
            targetKobo: 10000000,
            currentKobo: 2200000,
          ),
        ],
        owings: [
          Owing(
            id: 'owing-timi',
            type: OwingType.theyOweMe,
            person: 'Timi',
            amountKobo: 350000,
            date: now.subtract(const Duration(days: 6)),
            note: 'Lunch',
          ),
          Owing(
            id: 'owing-ada',
            type: OwingType.iOweThem,
            person: 'Ada',
            amountKobo: 1000000,
            date: now.subtract(const Duration(days: 3)),
            dueDate: now.add(const Duration(days: 2)),
          ),
        ],
        gigs: [
          GigRecord(
            id: 'gig-1',
            client: 'Teniola Studio',
            amountKobo: 4500000,
            date: now.subtract(const Duration(days: 2)),
            projectType: 'Design',
          ),
        ],
        bills: [
          BillReminder(
            id: 'bill-data',
            name: 'Monthly data',
            amountKobo: 1000000,
            frequency: 'Monthly',
            nextDue: now.add(const Duration(days: 3)),
          ),
          BillReminder(
            id: 'bill-hostel',
            name: 'Hostel dues',
            amountKobo: 7500000,
            frequency: 'Quarterly',
            nextDue: now.add(const Duration(days: 14)),
          ),
        ],
        watchedApps: const [
          WatchedApp(
            packageName: 'com.kuda.android',
            displayName: 'Kuda',
            enabled: true,
          ),
          WatchedApp(packageName: 'team.opay.pay', displayName: 'Opay'),
          WatchedApp(
            packageName: 'com.gtbank.gtworldv1',
            displayName: 'GTBank',
            enabled: true,
          ),
        ],
        partnerShares: [
          PartnerShare(
            id: 'share-1',
            partnerEmail: 'accountability@friend.ng',
            status: ShareStatus.active,
            permissions: const {
              'balance_summary',
              'budget_summary',
              'weekly_insights',
            },
            createdAt: now.subtract(const Duration(days: 4)),
          ),
        ],
        insights: [
          WeeklyInsight(
            id: 'insight-food',
            title: 'Late food spending is rising',
            body:
                'Most food expenses happened after 8pm this week. Kolo will flag the next snack run.',
            createdAt: now.subtract(const Duration(hours: 2)),
          ),
          WeeklyInsight(
            id: 'insight-gig',
            title: 'Gig income landed',
            body:
                'You received ₦45,000 from Teniola Studio. Protect at least ₦10,000 for savings.',
            createdAt: now.subtract(const Duration(days: 1)),
          ),
        ],
        permissions: const {
          KoloPermission.sms: PermissionGrantState.granted,
          KoloPermission.notifications: PermissionGrantState.notRequested,
          KoloPermission.overlay: PermissionGrantState.granted,
          KoloPermission.accessibility: PermissionGrantState.notRequested,
          KoloPermission.backgroundService: PermissionGrantState.notRequested,
        },
      ),
    );
  }

  DashboardState _state;
  final StreamController<DashboardState> _controller =
      StreamController<DashboardState>.broadcast();

  @override
  Stream<DashboardState> watchDashboard() async* {
    yield _state;
    yield* _controller.stream;
  }

  @override
  Future<void> adjustBalance(BalanceAdjustment adjustment) async {
    _state = _state.copyWith(
      balanceKobo: adjustment.newBalanceKobo,
      balanceAdjustments: [adjustment, ..._state.balanceAdjustments],
      aiMessages: [
        AiMessage(
          id: 'ai-${adjustment.id}',
          role: AiRole.assistant,
          content:
              'Balance updated to ${MoneyFormatter.formatKobo(adjustment.newBalanceKobo)}. I will use this for future checks.',
          timestamp: adjustment.createdAt,
          context: 'balance_adjustment',
        ),
        ..._state.aiMessages,
      ],
    );
    _controller.add(_state);
  }

  @override
  Future<void> upsertVault(SavingsVault vault) async {
    final otherVaults = _state.vaults
        .where((existing) => existing.id != vault.id)
        .toList(growable: false);
    _state = _state.copyWith(
      vaults: [vault, ...otherVaults],
      aiMessages: [
        AiMessage(
          id: 'ai-${vault.id}-${DateTime.now().microsecondsSinceEpoch}',
          role: AiRole.assistant,
          content:
              '${vault.name} is now protected at ${MoneyFormatter.formatKobo(vault.currentKobo)} of ${MoneyFormatter.formatKobo(vault.targetKobo)}.',
          timestamp: DateTime.now(),
          context: 'vault',
        ),
        ..._state.aiMessages,
      ],
    );
    _controller.add(_state);
  }

  @override
  Future<void> upsertOwing(Owing owing) async {
    final otherOwings = _state.owings
        .where((existing) => existing.id != owing.id)
        .toList(growable: false);
    _state = _state.copyWith(
      owings: [owing, ...otherOwings],
      aiMessages: [
        AiMessage(
          id: 'ai-${owing.id}-${DateTime.now().microsecondsSinceEpoch}',
          role: AiRole.assistant,
          content: owing.settled
              ? '${owing.person} is marked settled.'
              : '${owing.person} noted for ${MoneyFormatter.formatKobo(owing.amountKobo)}.',
          timestamp: DateTime.now(),
          context: 'owing',
        ),
        ..._state.aiMessages,
      ],
    );
    _controller.add(_state);
  }

  @override
  Future<void> upsertGig(GigRecord gig) async {
    final otherGigs = _state.gigs
        .where((existing) => existing.id != gig.id)
        .toList(growable: false);
    final transactionId = 'gig-income-${gig.id}';
    final existingTransaction = _state.transactions
        .where((transaction) => transaction.id == transactionId)
        .firstOrNull;
    final gigTransaction = TransactionRecord.income(
      id: transactionId,
      amountKobo: gig.amountKobo,
      category: 'Gig Income',
      description: '${gig.client} gig',
      date: gig.date,
      source: TransactionSource.manual,
      merchantName: gig.client,
      aiNote: 'Logged from Gig Tracker.',
    );
    final otherTransactions = _state.transactions
        .where((transaction) => transaction.id != transactionId)
        .toList(growable: false);
    final balanceDelta =
        gigTransaction.amountKobo - (existingTransaction?.amountKobo ?? 0);

    _state = _state.copyWith(
      balanceKobo: _state.balanceKobo + balanceDelta,
      gigs: [gig, ...otherGigs],
      transactions: [gigTransaction, ...otherTransactions],
      aiMessages: [
        AiMessage(
          id: 'ai-${gig.id}-${DateTime.now().microsecondsSinceEpoch}',
          role: AiRole.assistant,
          content:
              '${gig.client} gig logged for ${MoneyFormatter.formatKobo(gig.amountKobo)}. I will keep it visible in your income pattern.',
          timestamp: DateTime.now(),
          context: 'gig',
        ),
        ..._state.aiMessages,
      ],
    );
    _controller.add(_state);
  }

  @override
  Future<void> upsertBill(BillReminder bill) async {
    final otherBills = _state.bills
        .where((existing) => existing.id != bill.id)
        .toList(growable: false);
    _state = _state.copyWith(
      bills: [bill, ...otherBills],
      aiMessages: [
        AiMessage(
          id: 'ai-${bill.id}-${DateTime.now().microsecondsSinceEpoch}',
          role: AiRole.assistant,
          content: bill.active
              ? '${bill.name} reminder is set for ${MoneyFormatter.formatKobo(bill.amountKobo)}.'
              : '${bill.name} reminder is paused.',
          timestamp: DateTime.now(),
          context: 'bill',
        ),
        ..._state.aiMessages,
      ],
    );
    _controller.add(_state);
  }

  @override
  Future<void> upsertPartnerShare(PartnerShare share) async {
    final otherShares = _state.partnerShares
        .where((existing) => existing.id != share.id)
        .toList(growable: false);
    _state = _state.copyWith(
      partnerShares: [share, ...otherShares],
      aiMessages: [
        AiMessage(
          id: 'ai-${share.id}-${DateTime.now().microsecondsSinceEpoch}',
          role: AiRole.assistant,
          content: share.status == ShareStatus.revoked
              ? '${share.partnerEmail} no longer has partner visibility.'
              : '${share.partnerEmail} can see the selected summaries.',
          timestamp: DateTime.now(),
          context: 'partner_share',
        ),
        ..._state.aiMessages,
      ],
    );
    _controller.add(_state);
  }

  @override
  Future<PartnerSafeSummary?> publishPartnerSummary(PartnerShare share) async {
    return PartnerSummaryBuilder.build(
      dashboard: _state,
      share: share,
      generatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> upsertWatchedApp(WatchedApp app) async {
    final otherApps = _state.watchedApps
        .where((existing) => existing.packageName != app.packageName)
        .toList(growable: false);
    _state = _state.copyWith(
      watchedApps: [app, ...otherApps],
      aiMessages: [
        AiMessage(
          id: 'ai-${app.packageName}-${DateTime.now().microsecondsSinceEpoch}',
          role: AiRole.assistant,
          content: app.enabled
              ? '${app.displayName} is now watched.'
              : '${app.displayName} is no longer watched.',
          timestamp: DateTime.now(),
          context: 'watched_app',
        ),
        ..._state.aiMessages,
      ],
    );
    _controller.add(_state);
  }

  @override
  Future<void> logTransaction(TransactionRecord transaction) async {
    final alreadyLogged = _state.transactions.any(
      (existing) => existing.id == transaction.id,
    );
    if (alreadyLogged) return;

    final updatedTransactions = [transaction, ..._state.transactions];
    _state = _state.copyWith(
      balanceKobo: _state.balanceKobo + transaction.signedKobo,
      transactions: updatedTransactions,
      aiMessages: [
        AiMessage(
          id: 'ai-${transaction.id}',
          role: AiRole.assistant,
          content:
              '${transaction.description} noted. Balance is now ${MoneyFormatter.formatKobo(_state.balanceKobo + transaction.signedKobo)}.',
          timestamp: DateTime.now(),
          context: 'transaction',
        ),
        ..._state.aiMessages,
      ],
    );
    _controller.add(_state);
  }

  @override
  Future<void> recordAiMessage(AiMessage message) async {
    _state = _state.copyWith(aiMessages: [message, ..._state.aiMessages]);
    _controller.add(_state);
  }

  @override
  Future<void> clearAiMessages() async {
    _state = _state.copyWith(aiMessages: const []);
    _controller.add(_state);
  }

  @override
  Future<String> draftOwingReminder(Owing owing) async {
    final draft =
        'Hi ${owing.person}, gentle reminder about the ${MoneyFormatter.formatKobo(owing.amountKobo)} we noted. Please send it when you can.';
    await recordAiMessage(
      AiMessage(
        id: 'ai-reminder-${owing.id}-${DateTime.now().microsecondsSinceEpoch}',
        role: AiRole.assistant,
        content: draft,
        timestamp: DateTime.now(),
        context: 'owing_reminder',
      ),
    );
    return draft;
  }

  @override
  Future<WeeklyInsight> generateWeeklyInsight() async {
    final now = DateTime.now();
    final expenseTotal = _state.transactions
        .where((transaction) => transaction.type == TransactionType.expense)
        .fold<int>(0, (total, transaction) => total + transaction.amountKobo);
    final insight = WeeklyInsight(
      id: 'insight-${now.microsecondsSinceEpoch}',
      title: 'Kolo weekly spending check',
      body:
          'Kolo reviewed your week and found ${MoneyFormatter.formatKobo(expenseTotal)} in tracked spending. Keep protecting your vault money first.',
      createdAt: now,
    );
    _state = _state.copyWith(insights: [insight, ..._state.insights]);
    _controller.add(_state);
    return insight;
  }

  @override
  Future<BudgetPlan> completeOnboarding(
    OnboardingAnswers answers, {
    BudgetPlan? budget,
  }) async {
    final acceptedBudget = budget ?? await generateBudget(answers);
    if (budget != null) {
      _state = _state.copyWith(
        balanceKobo: answers.currentBalanceKobo,
        budgetPlan: acceptedBudget,
      );
    }
    _state = _state.copyWith(
      profile: _state.profile.copyWith(onboardingComplete: true),
      aiMessages: [
        AiMessage(
          id: 'ai-onboarding-${DateTime.now().microsecondsSinceEpoch}',
          role: AiRole.assistant,
          content:
              'Your first Kolo budget is ready. I kept ${answers.biggestProblem.toLowerCase()} in view and protected ${acceptedBudget.savingsGoal}.',
          timestamp: DateTime.now(),
          context: 'onboarding',
        ),
        ..._state.aiMessages,
      ],
    );
    _controller.add(_state);
    return acceptedBudget;
  }

  @override
  Future<BudgetPlan> generateBudget(OnboardingAnswers answers) async {
    final balance = answers.currentBalanceKobo;
    final budget = BudgetPlan(
      monthlyIncomeKobo: (balance * 2.4).round(),
      incomeType: answers.incomeFrequency.toLowerCase().contains('regular')
          ? 'regular'
          : 'irregular',
      savingsTargetKobo: (balance * 0.25).round(),
      savingsGoal: answers.savingsGoal ?? 'Emergency buffer',
      aiNotes:
          'Built around ${answers.incomeSource}. The biggest risk is ${answers.biggestProblem.toLowerCase()}, so flexible spending stays tight.',
      categories: [
        BudgetCategory(
          name: 'Food & Snacks',
          emoji: '🍜',
          allocatedKobo: (balance * 0.28).round(),
          priority: 1,
        ),
        BudgetCategory(
          name: 'Transport',
          emoji: '🚌',
          allocatedKobo: (balance * 0.16).round(),
          priority: 2,
        ),
        BudgetCategory(
          name: 'Data & Airtime',
          emoji: '📶',
          allocatedKobo: (balance * 0.10).round(),
          priority: 3,
        ),
        BudgetCategory(
          name: 'Savings',
          emoji: '🔒',
          allocatedKobo: (balance * 0.25).round(),
          priority: 0,
        ),
      ],
    );
    _state = _state.copyWith(
      balanceKobo: answers.currentBalanceKobo,
      budgetPlan: budget,
    );
    _controller.add(_state);
    return budget;
  }

  @override
  Future<AiMessage> sendAiMessage(String message) async {
    final userMessage = AiMessage(
      id: 'user-${DateTime.now().microsecondsSinceEpoch}',
      role: AiRole.user,
      content: message,
      timestamp: DateTime.now(),
      context: 'chat',
    );
    final assistantMessage = AiMessage(
      id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
      role: AiRole.assistant,
      content:
          'You have ${MoneyFormatter.formatKobo(_state.balanceKobo)}. I would keep ${MoneyFormatter.formatKobo(_state.budgetPlan.savingsTargetKobo)} protected and stay careful with food this week.',
      timestamp: DateTime.now(),
      context: 'chat',
    );

    _state = _state.copyWith(
      aiMessages: [assistantMessage, userMessage, ..._state.aiMessages],
    );
    _controller.add(_state);
    return assistantMessage;
  }

  @override
  Future<void> updateBudget(BudgetPlan budget) async {
    _state = _state.copyWith(budgetPlan: budget);
    _controller.add(_state);
  }

  @override
  Future<void> updatePermission(
    KoloPermission permission,
    PermissionGrantState state,
  ) async {
    _state = _state.copyWith(
      permissions: {..._state.permissions, permission: state},
    );
    _controller.add(_state);
  }

  @override
  Future<void> updatePreferredAiModel(String modelName) async {
    _state = _state.copyWith(
      profile: _state.profile.copyWith(
        preferredAiModel: koloAiModelNameOrDefault(modelName),
      ),
    );
    _controller.add(_state);
  }
}
