import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/ai_context_builder.dart';

void main() {
  test('builds full Gemini context from dashboard state', () {
    final now = DateTime(2026, 5, 24, 12);
    final state = DashboardState(
      profile: UserProfile(
        uid: 'user-1',
        name: 'Kolo Tester',
        email: 'tester@example.com',
        createdAt: DateTime(2026, 1),
        onboardingComplete: true,
      ),
      balanceKobo: 10000000,
      balanceAdjustments: const [],
      budgetPlan: const BudgetPlan(
        monthlyIncomeKobo: 12000000,
        incomeType: 'irregular',
        savingsTargetKobo: 3000000,
        savingsGoal: 'Emergency buffer',
        aiNotes: 'Protect savings first.',
        categories: [
          BudgetCategory(
            name: 'Food & Snacks',
            emoji: '*',
            allocatedKobo: 200000,
            priority: 1,
          ),
          BudgetCategory(
            name: 'Transport',
            emoji: '*',
            allocatedKobo: 100000,
            priority: 2,
          ),
        ],
      ),
      transactions: [
        TransactionRecord.expense(
          id: 'tx-food',
          amountKobo: 120000,
          category: 'Food & Snacks',
          description: 'Dinner',
          date: DateTime(2026, 5, 24, 20),
          source: TransactionSource.sms,
          merchantName: 'Chicken Republic',
        ),
        TransactionRecord.income(
          id: 'tx-gig',
          amountKobo: 2500000,
          category: 'Gig Income',
          description: 'Logo job',
          date: DateTime(2026, 5, 20),
          source: TransactionSource.manual,
          merchantName: 'Muna Foods',
        ),
        TransactionRecord.expense(
          id: 'tx-transport',
          amountKobo: 50000,
          category: 'Transport',
          description: 'Bolt',
          date: DateTime(2026, 5, 19),
          source: TransactionSource.notification,
          merchantName: 'Bolt',
        ),
      ],
      aiMessages: const [],
      vaults: [
        SavingsVault(
          id: 'vault-1',
          name: 'Rent',
          targetKobo: 3000000,
          currentKobo: 500000,
          deadline: DateTime(2026, 8),
        ),
      ],
      owings: const [],
      gigs: [
        GigRecord(
          id: 'gig-1',
          client: 'Muna Foods',
          amountKobo: 2500000,
          date: DateTime(2026, 5, 20),
          projectType: 'Brand kit',
        ),
      ],
      bills: [
        BillReminder(
          id: 'bill-due',
          name: 'Data renewal',
          amountKobo: 100000,
          frequency: 'monthly',
          nextDue: DateTime(2026, 5, 26),
        ),
        BillReminder(
          id: 'bill-later',
          name: 'Netflix',
          amountKobo: 350000,
          frequency: 'monthly',
          nextDue: DateTime(2026, 6, 10),
        ),
        BillReminder(
          id: 'bill-paused',
          name: 'Paused bill',
          amountKobo: 50000,
          frequency: 'weekly',
          nextDue: DateTime(2026, 5, 25),
          active: false,
        ),
      ],
      watchedApps: const [],
      partnerShares: const [],
      insights: const [],
      permissions: const {},
    );

    final payload = AiContextBuilder.build(state, now: now);

    expect(payload['balanceKobo'], 10000000);
    expect(payload['spendableBalanceKobo'], 9500000);
    expect(payload['vaultProtectionKobo'], 500000);
    expect(payload['daysSinceLastIncome'], 4);
    expect(payload['periodTotals'], {
      'incomeKobo': 2500000,
      'expenseKobo': 170000,
      'savingsKobo': 500000,
    });

    final categories = payload['budgetCategories'] as List<Object?>;
    expect(categories.first, containsPair('spentKobo', 120000));
    expect(categories.first, containsPair('remainingKobo', 80000));

    final dueBills = payload['dueBills'] as List<Object?>;
    expect(dueBills, hasLength(1));
    expect(dueBills.first, containsPair('name', 'Data renewal'));
    expect(dueBills.first, containsPair('daysUntilDue', 2));

    final gigSummary = payload['gigSummary'] as Map<String, Object?>;
    expect(gigSummary['totalThisMonthKobo'], 2500000);
    expect(gigSummary['totalThisYearKobo'], 2500000);
    expect(gigSummary['daysSinceLastGig'], 4);

    final spendingPatterns =
        payload['spendingPatterns'] as Map<String, Object?>;
    final weekdayPatterns =
        spendingPatterns['byWeekday'] as List<Map<String, Object?>>;
    final timePatterns =
        spendingPatterns['byTimeOfDay'] as List<Map<String, Object?>>;
    final categoryTimePatterns =
        spendingPatterns['byCategoryTimeOfDay'] as List<Map<String, Object?>>;
    expect(
      weekdayPatterns,
      contains(
        containsPair('weekday', 'Sunday'),
      ),
    );
    expect(weekdayPatterns.first, containsPair('expenseKobo', 120000));
    expect(
      timePatterns,
      contains(
        containsPair('window', 'evening'),
      ),
    );
    expect(timePatterns.first, containsPair('expenseKobo', 120000));
    expect(
      categoryTimePatterns,
      contains(
        allOf(
          containsPair('category', 'Food & Snacks'),
          containsPair('window', 'evening'),
          containsPair('expenseKobo', 120000),
        ),
      ),
    );

    final recentTransactions = payload['recentTransactions'] as List<Object?>;
    expect(recentTransactions.first, containsPair('source', 'sms'));
    expect(
      recentTransactions.first,
      containsPair('merchantName', 'Chicken Republic'),
    );
  });
}
