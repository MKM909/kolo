import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/services/financial_calculator.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/core/widgets/domain_widgets.dart';
import 'package:kolo/ui/core/widgets/kolo_scaffold.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
      data: (state) {
        final summary = FinancialCalculator.summarize(
          balanceKobo: state.balanceKobo,
          budget: state.budgetPlan,
          transactions: state.transactions,
          vaults: state.vaults,
        );

        return KoloGradientScaffold(
          title: 'Budget',
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            children: [
              KoloCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This month',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${MoneyFormatter.formatKobo(summary.totalExpenseKobo)} spent',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 170,
                      child: PieChart(
                        PieChartData(
                          centerSpaceRadius: 48,
                          sections: [
                            PieChartSectionData(
                              value: summary.totalIncomeKobo.toDouble(),
                              color: KoloColors.primary,
                              title: 'Earned',
                              radius: 42,
                            ),
                            PieChartSectionData(
                              value: summary.totalExpenseKobo.toDouble(),
                              color: KoloColors.expense,
                              title: 'Spent',
                              radius: 42,
                            ),
                            PieChartSectionData(
                              value: summary.balanceKobo.toDouble(),
                              color: KoloColors.income,
                              title: 'Balance',
                              radius: 42,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const KoloSectionHeader(title: 'Categories'),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final category in state.budgetPlan.categories)
                    BudgetCategoryCard(
                      category: category,
                      spentKobo: summary.categorySpendKobo[category.name] ?? 0,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
