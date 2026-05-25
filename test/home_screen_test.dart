import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/features/home/home_screen.dart';

void main() {
  testWidgets('home shows a friendly offline state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(
            (ref) => Stream<DashboardState>.error(StateError('offline')),
          ),
        ],
        child: MaterialApp(theme: KoloTheme.light, home: const HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_offline_state')), findsOneWidget);
    expect(find.text('Kolo is offline'), findsOneWidget);
    expect(find.textContaining('local cache'), findsOneWidget);
    expect(find.textContaining('StateError'), findsNothing);
  });

  testWidgets('home hides upcoming bills outside the due-soon window', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      _dashboardWithBills([
        BillReminder(
          id: 'bill-future',
          name: 'Hostel dues',
          amountKobo: 7500000,
          frequency: 'Quarterly',
          nextDue: DateTime.now().add(const Duration(days: 14)),
        ),
      ]),
    );

    expect(find.textContaining('Hostel dues is due soon'), findsNothing);
  });

  testWidgets('home hides paused bills from the due-soon banner', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      _dashboardWithBills([
        BillReminder(
          id: 'bill-paused',
          name: 'Paused data',
          amountKobo: 1000000,
          frequency: 'Monthly',
          nextDue: DateTime.now().add(const Duration(days: 1)),
          active: false,
        ),
      ]),
    );

    expect(find.textContaining('Paused data is due soon'), findsNothing);
  });

  testWidgets('home shows the nearest active due-soon bill', (tester) async {
    await _pumpHome(
      tester,
      _dashboardWithBills([
        BillReminder(
          id: 'bill-three-days',
          name: 'Data bundle',
          amountKobo: 1000000,
          frequency: 'Monthly',
          nextDue: DateTime.now().add(const Duration(days: 3)),
        ),
        BillReminder(
          id: 'bill-tomorrow',
          name: 'Airtime plan',
          amountKobo: 500000,
          frequency: 'Weekly',
          nextDue: DateTime.now().add(const Duration(days: 1)),
        ),
      ]),
    );

    expect(find.textContaining('Airtime plan is due soon'), findsOneWidget);
    expect(find.textContaining('Data bundle is due soon'), findsNothing);
  });

  testWidgets('manual expense prompts before dipping into vault funds', (
    tester,
  ) async {
    await _pumpHome(tester, _dashboardForVaultProtection());

    await tester.tap(find.text('Log Expense'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('transaction_amount')), '3000');
    await tester.enterText(
      find.byKey(const Key('transaction_description')),
      'Screen repair',
    );
    await tester.ensureVisible(find.byKey(const Key('save_transaction')));
    await tester.tap(find.byKey(const Key('save_transaction')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('spending_justification_prompt')),
      findsOneWidget,
    );
    expect(find.textContaining('protected vault money'), findsOneWidget);
    expect(find.textContaining('New Phone'), findsOneWidget);
  });
}

Future<void> _pumpHome(WidgetTester tester, DashboardState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardProvider.overrideWith((ref) => Stream.value(state)),
      ],
      child: MaterialApp(theme: KoloTheme.light, home: const HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

DashboardState _dashboardWithBills(List<BillReminder> bills) {
  return DashboardState(
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
    bills: bills,
    watchedApps: const [],
    partnerShares: const [],
    insights: const [],
    permissions: const {},
  );
}

DashboardState _dashboardForVaultProtection() {
  return _dashboardWithBills(const []).copyWith(
    balanceKobo: 2000000,
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
      aiNotes: 'Protect the phone vault first.',
    ),
    vaults: const [
      SavingsVault(
        id: 'vault-phone',
        name: 'New Phone',
        targetKobo: 6000000,
        currentKobo: 1800000,
      ),
    ],
  );
}
