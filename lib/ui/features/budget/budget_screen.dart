import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
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
                      onTap: () => _openCategorySheet(
                        context,
                        ref,
                        budget: state.budgetPlan,
                        category: category,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCategorySheet(
    BuildContext context,
    WidgetRef ref, {
    required BudgetPlan budget,
    required BudgetCategory category,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _BudgetCategorySheet(budget: budget, category: category, ref: ref),
    );
  }
}

class _BudgetCategorySheet extends StatefulWidget {
  const _BudgetCategorySheet({
    required this.budget,
    required this.category,
    required this.ref,
  });

  final BudgetPlan budget;
  final BudgetCategory category;
  final WidgetRef ref;

  @override
  State<_BudgetCategorySheet> createState() => _BudgetCategorySheetState();
}

class _BudgetCategorySheetState extends State<_BudgetCategorySheet> {
  late final TextEditingController _amountController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: (widget.category.allocatedKobo / 100).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        key: const Key('budget_category_sheet'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: Color(0xF0FFFFFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x20000000),
              blurRadius: 40,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.category.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Set the amount Kolo should reserve for this category.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: KoloColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('budget_category_amount'),
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monthly allocation',
                prefixText: '\u20A6 ',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: KoloColors.expense)),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              key: const Key('save_budget_category'),
              onPressed: _save,
              child: const Text('Save allocation'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final amountKobo = MoneyFormatter.parseNairaToKobo(
      _amountController.text.trim(),
    );
    if (amountKobo == null || amountKobo <= 0) {
      setState(() => _error = 'Enter a valid allocation.');
      return;
    }

    final updatedCategories = [
      for (final category in widget.budget.categories)
        category.name == widget.category.name
            ? BudgetCategory(
                name: category.name,
                emoji: category.emoji,
                allocatedKobo: amountKobo,
                priority: category.priority,
              )
            : category,
    ];

    await widget.ref
        .read(koloRepositoryProvider)
        .updateBudget(
          BudgetPlan(
            monthlyIncomeKobo: widget.budget.monthlyIncomeKobo,
            incomeType: widget.budget.incomeType,
            categories: updatedCategories,
            savingsTargetKobo: widget.budget.savingsTargetKobo,
            savingsGoal: widget.budget.savingsGoal,
            aiNotes: widget.budget.aiNotes,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }
}
