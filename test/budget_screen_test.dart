import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/features/budget/budget_screen.dart';

void main() {
  testWidgets('budget category cards show period transaction counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith((ref) => Stream.value(_dashboard)),
        ],
        child: MaterialApp(theme: KoloTheme.light, home: const BudgetScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('0 items'), findsOneWidget);
  });
}

final _now = DateTime(2026, 5, 24, 12);

final _dashboard = DashboardState(
  profile: UserProfile(
    uid: 'demo-user',
    name: 'Demo User',
    email: 'demo@kolo.app',
    createdAt: DateTime(2026, 5, 1),
    onboardingComplete: true,
  ),
  balanceKobo: 2000000,
  balanceAdjustments: const [],
  budgetPlan: const BudgetPlan(
    monthlyIncomeKobo: 5000000,
    incomeType: 'irregular',
    categories: [
      BudgetCategory(
        name: 'Food & Snacks',
        emoji: '*',
        allocatedKobo: 1500000,
        priority: 1,
      ),
      BudgetCategory(
        name: 'Transport',
        emoji: '*',
        allocatedKobo: 800000,
        priority: 2,
      ),
    ],
    savingsTargetKobo: 500000,
    savingsGoal: 'Emergency buffer',
    aiNotes: 'Keep snacks controlled.',
  ),
  transactions: [
    TransactionRecord.expense(
      id: 'tx-food-1',
      amountKobo: 300000,
      category: 'Food & Snacks',
      description: 'Lunch',
      date: _now,
      source: TransactionSource.manual,
    ),
    TransactionRecord.expense(
      id: 'tx-food-2',
      amountKobo: 200000,
      category: 'Food & Snacks',
      description: 'Dinner',
      date: _now.subtract(const Duration(days: 1)),
      source: TransactionSource.manual,
    ),
    TransactionRecord.expense(
      id: 'tx-transport-old',
      amountKobo: 100000,
      category: 'Transport',
      description: 'Old ride',
      date: _now.subtract(const Duration(days: 12)),
      source: TransactionSource.manual,
    ),
  ],
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
