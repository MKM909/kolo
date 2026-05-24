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
}
