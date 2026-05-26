import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/ai_override_tone.dart';
import 'package:kolo/domain/services/bill_protection_advisor.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/domain/services/spending_justification_advisor.dart';
import 'package:kolo/domain/services/vault_protection_advisor.dart';

class LocalSpendingJustificationAdvisor
    implements SpendingJustificationAdvisor {
  const LocalSpendingJustificationAdvisor();

  @override
  Future<SpendingJustificationDecision> evaluateSpendingJustification({
    required DashboardState context,
    required TransactionRecord transaction,
    required String justification,
    String? modelName,
  }) async {
    final adjustedTonePrefix =
        AiOverrideTone.shouldAdjustTone(context.transactions)
        ? '${AiOverrideTone.repeatedOverrideMessage} '
        : '';
    final vaultWarning = VaultProtectionAdvisor.check(
      balanceKobo: context.balanceKobo,
      expenseKobo: transaction.amountKobo,
      vaults: context.vaults,
    );
    if (vaultWarning.dipsIntoVault) {
      final vaultName = vaultWarning.primaryVaultName ?? 'a vault';
      final note =
          '${adjustedTonePrefix}Caution - $justification. This would touch ${MoneyFormatter.formatKobo(vaultWarning.shortfallKobo)} of protected vault money for $vaultName.';
      return SpendingJustificationDecision(
        status: SpendingDecisionStatus.caution,
        message: note,
        aiNote: note,
      );
    }

    final billWarning = BillProtectionAdvisor.check(
      balanceKobo: context.balanceKobo,
      expenseKobo: transaction.amountKobo,
      bills: context.bills,
    );
    if (billWarning.risksDueBills) {
      final billName = billWarning.primaryBillName ?? 'a bill';
      final note =
          '${adjustedTonePrefix}Caution - $justification. This would leave you ${MoneyFormatter.formatKobo(billWarning.shortfallKobo)} short for $billName, a bill due soon.';
      return SpendingJustificationDecision(
        status: SpendingDecisionStatus.caution,
        message: note,
        aiNote: note,
      );
    }

    final allocatedKobo = _categoryBudgetKobo(context, transaction.category);
    final spendAfter =
        _categorySpendKobo(context, transaction.category) +
        transaction.amountKobo;
    final overBy = spendAfter - allocatedKobo;
    if (allocatedKobo > 0 && overBy > 0) {
      final note =
          '${adjustedTonePrefix}Caution - $justification. This leaves you ${MoneyFormatter.formatKobo(overBy)} over ${transaction.category}.';
      return SpendingJustificationDecision(
        status: SpendingDecisionStatus.caution,
        message: note,
        aiNote: note,
      );
    }

    final note =
        '${adjustedTonePrefix}Approved - $justification. Kolo reviewed it against your current balance.';
    return SpendingJustificationDecision(
      status: SpendingDecisionStatus.approved,
      message: note,
      aiNote: note,
    );
  }

  int _categoryBudgetKobo(DashboardState dashboard, String categoryName) {
    for (final category in dashboard.budgetPlan.categories) {
      if (category.name == categoryName) return category.allocatedKobo;
    }
    return 0;
  }

  int _categorySpendKobo(DashboardState dashboard, String categoryName) {
    return dashboard.transactions
        .where(
          (transaction) =>
              transaction.type == TransactionType.expense &&
              transaction.category == categoryName,
        )
        .fold<int>(0, (total, transaction) => total + transaction.amountKobo);
  }
}
