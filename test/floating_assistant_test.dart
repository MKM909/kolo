import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/kolo_app.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/data/repositories/fake_kolo_repository.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/core/widgets/kolo_liquid_aether_orb.dart';
import 'package:kolo/ui/features/assistant/kolo_floating_assistant.dart';

void main() {
  testWidgets('shell shows liquid aether Kolo assistant bubble', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kolo_floating_assistant')), findsOneWidget);
    expect(find.byKey(const Key('kolo_liquid_aether_orb')), findsOneWidget);
    expect(find.text('Need a quick money check?'), findsOneWidget);
  });

  testWidgets('liquid aether orb animates its inner surface', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KoloLiquidAetherOrb(debugAnimateInWidgetTests: true),
        ),
      ),
    );

    expect(
      find.byKey(const Key('kolo_liquid_aether_animation')),
      findsOneWidget,
    );
  });

  testWidgets('liquid aether orb keeps moving after one animation cycle', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KoloLiquidAetherOrb(debugAnimateInWidgetTests: true),
        ),
      ),
    );

    final builderFinder = find.byKey(const Key('kolo_liquid_aether_animation'));
    final firstCycleAnimation =
        tester.widget<AnimatedBuilder>(builderFinder).animation
            as Animation<double>;

    await tester.pump(const Duration(milliseconds: 3700));
    final valueAfterCycle = firstCycleAnimation.value;
    await tester.pump(const Duration(milliseconds: 180));

    expect(firstCycleAnimation.value, isNot(valueAfterCycle));
  });

  testWidgets(
    'floating assistant opens a conversation panel and sends a reply',
    (tester) async {
      await tester.pumpWidget(const KoloApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('kolo_liquid_aether_orb')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('kolo_floating_conversation')),
        findsOneWidget,
      );
      expect(find.text('Ask Kolo from anywhere'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('kolo_floating_input')),
        'Can I afford data?',
      );
      await tester.tap(find.byKey(const Key('kolo_floating_send')));
      await tester.pumpAndSettle();

      expect(find.text('Can I afford data?'), findsOneWidget);
    },
  );

  testWidgets('floating assistant quick actions send suggested prompts', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('kolo_liquid_aether_orb')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('kolo_quick_tell_more')));
    await tester.pumpAndSettle();

    expect(find.text('Tell me more about this money check.'), findsOneWidget);
  });

  testWidgets('floating assistant opens category correction', (
    tester,
  ) async {
    await tester.pumpWidget(const KoloApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('kolo_liquid_aether_orb')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kolo_quick_wrong_category')), findsOneWidget);

    await tester.tap(find.byKey(const Key('kolo_quick_wrong_category')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('kolo_assistant_category_sheet')),
      findsOneWidget,
    );
  });

  testWidgets('floating assistant Wrong category updates a transaction', (
    tester,
  ) async {
    final repository = FakeKoloRepository.seeded();
    await repository.logTransaction(
      TransactionRecord.expense(
        id: 'tx-wrong-category',
        amountKobo: 180000,
        category: 'Food & Snacks',
        description: 'Bolt ride to campus',
        date: DateTime(2026, 5, 26, 9),
        source: TransactionSource.manual,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [koloRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: KoloTheme.light,
          home: const Scaffold(
            body: Stack(children: [KoloFloatingAssistant()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('kolo_liquid_aether_orb')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kolo_quick_wrong_category')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('kolo_assistant_category_sheet')),
      findsOneWidget,
    );
    expect(find.text('Bolt ride to campus'), findsWidgets);

    await tester.tap(
      find.byKey(const Key('kolo_assistant_category_dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transport').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('kolo_assistant_category_save')),
    );
    await tester.tap(find.byKey(const Key('kolo_assistant_category_save')));
    await tester.pumpAndSettle();

    final dashboard = await repository.watchDashboard().first;
    final transaction = dashboard.transactions.firstWhere(
      (transaction) => transaction.id == 'tx-wrong-category',
    );
    expect(transaction.category, 'Transport');
  });

  testWidgets('floating assistant Log it records a manual expense', (
    tester,
  ) async {
    final repository = FakeKoloRepository.seeded();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [koloRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: KoloTheme.light,
          home: const Scaffold(
            body: Stack(children: [KoloFloatingAssistant()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('kolo_liquid_aether_orb')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kolo_quick_log_it')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kolo_assistant_log_sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('kolo_assistant_log_amount')),
      '2500',
    );
    await tester.enterText(
      find.byKey(const Key('kolo_assistant_log_description')),
      'Bolt ride to campus',
    );
    await tester.ensureVisible(find.byKey(const Key('kolo_assistant_log_save')));
    await tester.tap(find.byKey(const Key('kolo_assistant_log_save')));
    await tester.pumpAndSettle();

    final dashboard = await repository.watchDashboard().first;
    final transaction = dashboard.transactions.first;
    expect(transaction.description, 'Bolt ride to campus');
    expect(transaction.amountKobo, 250000);
    expect(transaction.type, TransactionType.expense);
    expect(transaction.source, TransactionSource.manual);
  });

  testWidgets('floating assistant warns when balance is negative', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(
            (ref) => Stream<DashboardState>.value(
              _dashboardState(balanceKobo: -450000),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Stack(children: [KoloFloatingAssistant()])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Your balance is in the red, let's talk"), findsOneWidget);
    expect(find.byKey(const Key('kolo_assistant_alert_badge')), findsOneWidget);
  });

  testWidgets('floating assistant can close while offline', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(
            (ref) => Stream<DashboardState>.error(StateError('offline')),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Stack(children: [KoloFloatingAssistant()])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('kolo_liquid_aether_orb')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kolo_floating_conversation')), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);

    await tester.tap(find.byTooltip('Close Kolo'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kolo_floating_conversation')), findsNothing);
    expect(find.byKey(const Key('kolo_liquid_aether_orb')), findsOneWidget);
  });
}

DashboardState _dashboardState({required int balanceKobo}) {
  return DashboardState(
    profile: UserProfile(
      uid: 'test-user',
      name: 'Micah',
      email: 'micah@kolo.app',
      createdAt: DateTime(2026, 5, 24),
      onboardingComplete: true,
    ),
    balanceKobo: balanceKobo,
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
    permissions: const {},
  );
}
