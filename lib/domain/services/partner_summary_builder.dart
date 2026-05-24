import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/financial_calculator.dart';

class PartnerSafeSummary {
  const PartnerSafeSummary({
    required this.shareId,
    required this.partnerEmail,
    required this.generatedAt,
    required this.permissions,
    required this.sections,
  });

  final String shareId;
  final String partnerEmail;
  final DateTime generatedAt;
  final Set<String> permissions;
  final Map<String, Object?> sections;

  Map<String, Object?> toJson() {
    return {
      'shareId': shareId,
      'partnerEmail': partnerEmail,
      'generatedAt': generatedAt.toIso8601String(),
      'permissions': permissions.toList()..sort(),
      'sections': sections,
    };
  }
}

class PartnerSummaryBuilder {
  PartnerSummaryBuilder._();

  static PartnerSafeSummary? build({
    required DashboardState dashboard,
    required PartnerShare share,
    required DateTime generatedAt,
  }) {
    if (share.status != ShareStatus.active) return null;

    final summary = FinancialCalculator.summarize(
      balanceKobo: dashboard.balanceKobo,
      budget: dashboard.budgetPlan,
      transactions: dashboard.transactions,
      vaults: dashboard.vaults,
    );
    final sections = <String, Object?>{};

    if (share.permissions.contains('balance_summary')) {
      sections['balance_summary'] = {
        'balanceKobo': summary.balanceKobo,
        'totalIncomeKobo': summary.totalIncomeKobo,
        'totalExpenseKobo': summary.totalExpenseKobo,
        'totalSavingsKobo': summary.totalSavingsKobo,
      };
    }

    if (share.permissions.contains('budget_summary')) {
      sections['budget_summary'] = {
        'totalBudgetKobo': summary.totalBudgetKobo,
        'categories': [
          for (final category in dashboard.budgetPlan.categories)
            {
              'name': category.name,
              'allocatedKobo': category.allocatedKobo,
              'spentKobo': summary.categorySpendKobo[category.name] ?? 0,
            },
        ],
      };
    }

    if (share.permissions.contains('vault_goals')) {
      sections['vault_goals'] = {
        'count': dashboard.vaults.length,
        'totalTargetKobo': dashboard.vaults.fold<int>(
          0,
          (total, vault) => total + vault.targetKobo,
        ),
        'totalCurrentKobo': summary.totalSavingsKobo,
      };
    }

    if (share.permissions.contains('owings')) {
      sections['owings'] = {
        'unsettledCount': dashboard.owings
            .where((owing) => !owing.settled)
            .length,
        'theyOweMeKobo': dashboard.owings
            .where(
              (owing) => !owing.settled && owing.type == OwingType.theyOweMe,
            )
            .fold<int>(0, (total, owing) => total + owing.amountKobo),
        'iOweThemKobo': dashboard.owings
            .where(
              (owing) => !owing.settled && owing.type == OwingType.iOweThem,
            )
            .fold<int>(0, (total, owing) => total + owing.amountKobo),
      };
    }

    if (share.permissions.contains('bills')) {
      final activeBills = dashboard.bills.where((bill) => bill.active).toList();
      sections['bills'] = {
        'activeCount': activeBills.length,
        'totalActiveKobo': activeBills.fold<int>(
          0,
          (total, bill) => total + bill.amountKobo,
        ),
      };
    }

    if (share.permissions.contains('weekly_insights')) {
      sections['weekly_insights'] = {
        'count': dashboard.insights.length,
        'titles': [
          for (final insight in dashboard.insights.take(3)) insight.title,
        ],
      };
    }

    return PartnerSafeSummary(
      shareId: share.id,
      partnerEmail: share.partnerEmail,
      generatedAt: generatedAt,
      permissions: share.permissions,
      sections: sections,
    );
  }
}
