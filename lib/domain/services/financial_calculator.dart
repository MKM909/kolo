import 'package:kolo/domain/models/models.dart';

class FinancialCalculator {
  FinancialCalculator._();

  static FinancialSummary summarize({
    required int balanceKobo,
    required BudgetPlan budget,
    required List<TransactionRecord> transactions,
    required List<SavingsVault> vaults,
  }) {
    var income = 0;
    var expense = 0;
    final spendByCategory = <String, int>{};

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        income += transaction.amountKobo;
      } else {
        expense += transaction.amountKobo;
        spendByCategory.update(
          transaction.category,
          (value) => value + transaction.amountKobo,
          ifAbsent: () => transaction.amountKobo,
        );
      }
    }

    final savings = vaults.fold(0, (total, vault) => total + vault.currentKobo);

    return FinancialSummary(
      balanceKobo: balanceKobo,
      totalIncomeKobo: income,
      totalExpenseKobo: expense,
      totalSavingsKobo: savings,
      categorySpendKobo: spendByCategory,
      categoryBudgetKobo: {
        for (final category in budget.categories)
          category.name: category.allocatedKobo,
      },
      totalBudgetKobo: budget.totalAllocatedKobo,
    );
  }
}
