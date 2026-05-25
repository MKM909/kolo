import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/repositories/fake_kolo_repository.dart';
import 'package:kolo/domain/models/models.dart';

void main() {
  test('fake repository logs expenses and updates balance', () async {
    final repository = FakeKoloRepository.seeded();
    final initial = await repository.watchDashboard().first;

    await repository.logTransaction(
      TransactionRecord.expense(
        id: 'manual-food',
        amountKobo: 250000,
        category: 'Food & Snacks',
        description: 'Dinner',
        date: DateTime(2026, 5, 24),
        source: TransactionSource.manual,
      ),
    );

    final updated = await repository.watchDashboard().first;

    expect(updated.balanceKobo, initial.balanceKobo - 250000);
    expect(updated.transactions.first.description, 'Dinner');
  });

  test('fake repository ignores duplicate transaction ids', () async {
    final repository = FakeKoloRepository.seeded();
    final initial = await repository.watchDashboard().first;
    final transaction = TransactionRecord.expense(
      id: 'native-sms-dupe',
      amountKobo: 250000,
      category: 'Food & Snacks',
      description: 'Dinner',
      date: DateTime(2026, 5, 24),
      source: TransactionSource.sms,
    );

    await repository.logTransaction(transaction);
    await repository.logTransaction(transaction);

    final updated = await repository.watchDashboard().first;

    expect(updated.balanceKobo, initial.balanceKobo - 250000);
    expect(
      updated.transactions.where((tx) => tx.id == 'native-sms-dupe'),
      hasLength(1),
    );
  });

  test(
    'fake repository updates transaction category without changing balance',
    () async {
      final repository = FakeKoloRepository.seeded();
      final initial = await repository.watchDashboard().first;

      await repository.updateTransactionCategory(
        transactionId: 'tx-food',
        category: 'Transport',
      );

      final updated = await repository.watchDashboard().first;

      expect(updated.balanceKobo, initial.balanceKobo);
      expect(
        updated.transactions
            .singleWhere((transaction) => transaction.id == 'tx-food')
            .category,
        'Transport',
      );
      expect(updated.aiMessages.first.context, 'transaction_category');
    },
  );

  test('fake repository records balance adjustments', () async {
    final repository = FakeKoloRepository.seeded();
    final initial = await repository.watchDashboard().first;

    await repository.adjustBalance(
      BalanceAdjustment(
        id: 'adjust-balance',
        previousBalanceKobo: initial.balanceKobo,
        newBalanceKobo: 6000000,
        note: 'Matched bank app',
        createdAt: DateTime(2026, 5, 24),
      ),
    );

    final updated = await repository.watchDashboard().first;

    expect(updated.balanceKobo, 6000000);
    expect(updated.balanceAdjustments.single.note, 'Matched bank app');
    expect(updated.aiMessages.first.context, 'balance_adjustment');
  });

  test('fake repository creates and updates savings vaults', () async {
    final repository = FakeKoloRepository.seeded();

    await repository.upsertVault(
      SavingsVault(
        id: 'vault-trip',
        name: 'Detty December',
        targetKobo: 25000000,
        currentKobo: 500000,
        deadline: DateTime(2026, 12, 1),
      ),
    );

    var dashboard = await repository.watchDashboard().first;
    expect(dashboard.vaults.first.name, 'Detty December');
    expect(dashboard.vaults.first.progress, closeTo(0.02, 0.001));

    await repository.upsertVault(
      SavingsVault(
        id: 'vault-trip',
        name: 'Detty December',
        targetKobo: 25000000,
        currentKobo: 750000,
        deadline: DateTime(2026, 12, 1),
      ),
    );

    dashboard = await repository.watchDashboard().first;
    expect(dashboard.vaults.first.currentKobo, 750000);
    expect(
      dashboard.vaults.where((vault) => vault.id == 'vault-trip'),
      hasLength(1),
    );
    expect(dashboard.aiMessages.first.context, 'vault');
  });

  test('fake repository celebrates vault funding milestones', () async {
    final repository = FakeKoloRepository.seeded();

    await repository.upsertVault(
      const SavingsVault(
        id: 'vault-tablet',
        name: 'Tablet',
        targetKobo: 1000000,
        currentKobo: 400000,
      ),
    );
    await repository.upsertVault(
      const SavingsVault(
        id: 'vault-tablet',
        name: 'Tablet',
        targetKobo: 1000000,
        currentKobo: 500000,
      ),
    );

    final dashboard = await repository.watchDashboard().first;

    expect(dashboard.aiMessages.first.context, 'vault');
    expect(dashboard.aiMessages.first.content, contains('halfway'));
    expect(dashboard.aiMessages.first.content, contains('Tablet'));
  });

  test('fake repository deletes savings vaults', () async {
    final repository = FakeKoloRepository.seeded();

    await repository.deleteVault('vault-phone');

    final dashboard = await repository.watchDashboard().first;
    expect(
      dashboard.vaults.where((vault) => vault.id == 'vault-phone'),
      isEmpty,
    );
    expect(dashboard.aiMessages.first.context, 'vault');
    expect(dashboard.aiMessages.first.content, contains('removed'));
  });

  test('fake repository creates and updates owings', () async {
    final repository = FakeKoloRepository.seeded();

    await repository.upsertOwing(
      Owing(
        id: 'owing-sade',
        type: OwingType.theyOweMe,
        person: 'Sade',
        amountKobo: 1200000,
        date: DateTime(2026, 5, 24),
        note: 'Design deposit',
      ),
    );

    var dashboard = await repository.watchDashboard().first;
    expect(dashboard.owings.first.person, 'Sade');
    expect(dashboard.owings.first.settled, isFalse);

    await repository.upsertOwing(
      Owing(
        id: 'owing-sade',
        type: OwingType.theyOweMe,
        person: 'Sade',
        amountKobo: 1200000,
        date: DateTime(2026, 5, 24),
        settled: true,
        note: 'Design deposit',
      ),
    );

    dashboard = await repository.watchDashboard().first;
    expect(dashboard.owings.first.settled, isTrue);
    expect(
      dashboard.owings.where((owing) => owing.id == 'owing-sade'),
      hasLength(1),
    );
    expect(dashboard.aiMessages.first.context, 'owing');
  });

  test('fake repository deletes owing records', () async {
    final repository = FakeKoloRepository.seeded();

    await repository.deleteOwing('owing-timi');

    final dashboard = await repository.watchDashboard().first;
    expect(
      dashboard.owings.where((owing) => owing.id == 'owing-timi'),
      isEmpty,
    );
    expect(dashboard.aiMessages.first.context, 'owing');
    expect(dashboard.aiMessages.first.content, contains('removed'));
  });

  test('fake repository creates and updates gig records', () async {
    final repository = FakeKoloRepository.seeded();
    final initial = await repository.watchDashboard().first;

    await repository.upsertGig(
      GigRecord(
        id: 'gig-brand',
        client: 'Muna Foods',
        amountKobo: 8500000,
        date: DateTime(2026, 5, 24),
        projectType: 'Brand kit',
        note: 'Half paid upfront',
      ),
    );

    var dashboard = await repository.watchDashboard().first;
    expect(dashboard.gigs.first.client, 'Muna Foods');
    expect(dashboard.gigs.first.projectType, 'Brand kit');
    expect(dashboard.balanceKobo, initial.balanceKobo + 8500000);
    expect(
      dashboard.transactions.where((tx) => tx.id == 'gig-income-gig-brand'),
      hasLength(1),
    );
    expect(dashboard.transactions.first.category, 'Gig Income');

    await repository.upsertGig(
      GigRecord(
        id: 'gig-brand',
        client: 'Muna Foods',
        amountKobo: 9000000,
        date: DateTime(2026, 5, 24),
        projectType: 'Brand kit',
        note: 'Added social templates',
      ),
    );

    dashboard = await repository.watchDashboard().first;
    expect(dashboard.gigs.first.amountKobo, 9000000);
    expect(dashboard.gigs.where((gig) => gig.id == 'gig-brand'), hasLength(1));
    expect(dashboard.balanceKobo, initial.balanceKobo + 9000000);
    expect(
      dashboard.transactions.where((tx) => tx.id == 'gig-income-gig-brand'),
      hasLength(1),
    );
    expect(dashboard.aiMessages.first.context, 'gig');
  });

  test('fake repository creates and updates bill reminders', () async {
    final repository = FakeKoloRepository.seeded();
    final dueDate = DateTime(2026, 6, 1);

    await repository.upsertBill(
      BillReminder(
        id: 'bill-wifi',
        name: 'Wifi subscription',
        amountKobo: 1800000,
        frequency: 'Monthly',
        nextDue: dueDate,
      ),
    );

    var dashboard = await repository.watchDashboard().first;
    expect(dashboard.bills.first.name, 'Wifi subscription');
    expect(dashboard.bills.first.active, isTrue);

    await repository.upsertBill(
      BillReminder(
        id: 'bill-wifi',
        name: 'Wifi subscription',
        amountKobo: 1800000,
        frequency: 'Monthly',
        nextDue: dueDate,
        active: false,
      ),
    );

    dashboard = await repository.watchDashboard().first;
    expect(dashboard.bills.first.active, isFalse);
    expect(
      dashboard.bills.where((bill) => bill.id == 'bill-wifi'),
      hasLength(1),
    );
    expect(dashboard.aiMessages.first.context, 'bill');
  });

  test('fake repository deletes bill reminders', () async {
    final repository = FakeKoloRepository.seeded();

    await repository.deleteBill('bill-data');

    final dashboard = await repository.watchDashboard().first;
    expect(dashboard.bills.where((bill) => bill.id == 'bill-data'), isEmpty);
    expect(dashboard.aiMessages.first.context, 'bill');
    expect(dashboard.aiMessages.first.content, contains('removed'));
  });

  test('fake repository creates and revokes partner shares', () async {
    final repository = FakeKoloRepository.seeded();
    final createdAt = DateTime(2026, 5, 24);

    await repository.upsertPartnerShare(
      PartnerShare(
        id: 'share-ade',
        partnerEmail: 'ade@example.com',
        status: ShareStatus.pending,
        permissions: const {'balance_summary', 'budget_summary'},
        createdAt: createdAt,
      ),
    );

    var dashboard = await repository.watchDashboard().first;
    expect(dashboard.partnerShares.first.partnerEmail, 'ade@example.com');
    expect(
      dashboard.partnerShares.first.permissions,
      contains('budget_summary'),
    );

    await repository.upsertPartnerShare(
      PartnerShare(
        id: 'share-ade',
        partnerEmail: 'ade@example.com',
        status: ShareStatus.revoked,
        permissions: const {'balance_summary'},
        createdAt: createdAt,
        revokedAt: DateTime(2026, 5, 25),
      ),
    );

    dashboard = await repository.watchDashboard().first;
    expect(dashboard.partnerShares.first.status, ShareStatus.revoked);
    expect(
      dashboard.partnerShares.where((share) => share.id == 'share-ade'),
      hasLength(1),
    );
    expect(dashboard.aiMessages.first.context, 'partner_share');
  });

  test(
    'fake repository keeps only one pending or active partner share',
    () async {
      final repository = FakeKoloRepository.seeded();

      await repository.upsertPartnerShare(
        PartnerShare(
          id: 'share-ade',
          partnerEmail: 'ade@example.com',
          status: ShareStatus.pending,
          permissions: const {'balance_summary'},
          createdAt: DateTime(2026, 5, 24),
        ),
      );

      final dashboard = await repository.watchDashboard().first;
      final visibleShares = dashboard.partnerShares.where(
        (share) => share.status != ShareStatus.revoked,
      );

      expect(visibleShares, hasLength(1));
      expect(visibleShares.single.partnerEmail, 'ade@example.com');
      expect(
        dashboard.partnerShares.singleWhere((share) => share.id == 'share-1'),
        isA<PartnerShare>().having(
          (share) => share.status,
          'status',
          ShareStatus.revoked,
        ),
      );
    },
  );

  test('fake repository enables and disables watched apps', () async {
    final repository = FakeKoloRepository.seeded();

    await repository.upsertWatchedApp(
      const WatchedApp(
        packageName: 'com.moniebank.personal',
        displayName: 'Moniepoint',
        enabled: true,
      ),
    );

    var dashboard = await repository.watchDashboard().first;
    expect(dashboard.watchedApps.first.displayName, 'Moniepoint');
    expect(dashboard.watchedApps.first.enabled, isTrue);

    await repository.upsertWatchedApp(
      const WatchedApp(
        packageName: 'com.moniebank.personal',
        displayName: 'Moniepoint',
        enabled: false,
      ),
    );

    dashboard = await repository.watchDashboard().first;
    expect(dashboard.watchedApps.first.enabled, isFalse);
    expect(
      dashboard.watchedApps.where(
        (app) => app.packageName == 'com.moniebank.personal',
      ),
      hasLength(1),
    );
    expect(dashboard.aiMessages.first.context, 'watched_app');
  });

  test(
    'fake repository stores the preferred Gemini model on the profile',
    () async {
      final repository = FakeKoloRepository.seeded();

      await repository.updatePreferredAiModel('gemini-3.1-flash');
      final dashboard = await repository.watchDashboard().first;

      expect(dashboard.profile.preferredAiModel, 'gemini-3.1-flash');
    },
  );

  test(
    'fake repository stores notification preferences on the profile',
    () async {
      final repository = FakeKoloRepository.seeded();

      await repository.updateNotificationPreferences(
        const NotificationPreferences(
          transactionAlerts: true,
          budgetWarnings: false,
          billReminders: true,
          weeklyInsights: false,
          bubbleInterventions: true,
        ),
      );
      final dashboard = await repository.watchDashboard().first;

      expect(
        dashboard.profile.notificationPreferences.transactionAlerts,
        isTrue,
      );
      expect(dashboard.profile.notificationPreferences.budgetWarnings, isFalse);
      expect(dashboard.profile.notificationPreferences.billReminders, isTrue);
      expect(dashboard.profile.notificationPreferences.weeklyInsights, isFalse);
      expect(
        dashboard.profile.notificationPreferences.bubbleInterventions,
        isTrue,
      );
    },
  );

  test('fake AI returns an onboarding budget and stores messages', () async {
    final repository = FakeKoloRepository.seeded();

    final budget = await repository.generateBudget(
      const OnboardingAnswers(
        incomeSource: 'Freelance and family support',
        incomeFrequency: 'Irregular',
        currentBalanceKobo: 5000000,
        biggestProblem: 'Snacks',
        savingsGoal: 'Laptop',
      ),
    );

    final response = await repository.sendAiMessage('Can I afford food?');
    final dashboard = await repository.watchDashboard().first;

    expect(budget.categories, isNotEmpty);
    expect(response.content, contains('₦'));
    expect(dashboard.aiMessages.length, greaterThanOrEqualTo(2));
  });

  test('fake AI budget generation is side-effect-free until accepted', () async {
    final repository = FakeKoloRepository.seeded();
    final initial = await repository.watchDashboard().first;

    final budget = await repository.generateBudget(
      const OnboardingAnswers(
        incomeSource: 'Freelance design',
        incomeFrequency: 'Irregular gigs',
        currentBalanceKobo: 4200000,
        biggestProblem: 'Impulse snacks',
        savingsGoal: 'Laptop',
      ),
    );
    final dashboard = await repository.watchDashboard().first;

    expect(budget.savingsGoal, 'Laptop');
    expect(dashboard.balanceKobo, initial.balanceKobo);
    expect(dashboard.budgetPlan.aiNotes, initial.budgetPlan.aiNotes);
    expect(
      dashboard.profile.onboardingComplete,
      initial.profile.onboardingComplete,
    );
  });

  test(
    'fake repository completes onboarding with balance and budget',
    () async {
      final repository = FakeKoloRepository.seeded();

      final budget = await repository.completeOnboarding(
        const OnboardingAnswers(
          incomeSource: 'Freelance design',
          incomeFrequency: 'Irregular gigs',
          currentBalanceKobo: 4200000,
          biggestProblem: 'Impulse snacks',
          savingsGoal: 'Laptop',
        ),
      );
      final dashboard = await repository.watchDashboard().first;

      expect(budget.savingsGoal, 'Laptop');
      expect(dashboard.balanceKobo, 4200000);
      expect(dashboard.budgetPlan.aiNotes, contains('Freelance design'));
      expect(dashboard.profile.onboardingComplete, isTrue);
      expect(dashboard.aiMessages.first.context, 'onboarding');
    },
  );

  test('fake repository generates and stores a weekly insight', () async {
    final repository = FakeKoloRepository.seeded();
    final initial = await repository.watchDashboard().first;

    final insight = await repository.generateWeeklyInsight();
    final updated = await repository.watchDashboard().first;

    expect(updated.insights, hasLength(initial.insights.length + 1));
    expect(updated.insights.first.id, insight.id);
    expect(updated.insights.first.title, isNotEmpty);
    expect(updated.insights.first.body, contains('Kolo'));
  });

  test('fake repository publishes a partner-safe summary', () async {
    final repository = FakeKoloRepository.seeded();
    final dashboard = await repository.watchDashboard().first;

    final summary = await repository.publishPartnerSummary(
      dashboard.partnerShares.first,
    );

    expect(summary, isNotNull);
    expect(summary!.partnerEmail, 'accountability@friend.ng');
    expect(summary.sections.keys, contains('balance_summary'));
    expect(summary.toJson().toString(), isNot(contains('Chicken Republic')));
  });
}
