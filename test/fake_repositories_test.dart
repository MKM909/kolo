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

  test('fake repository creates and updates gig records', () async {
    final repository = FakeKoloRepository.seeded();

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
}
