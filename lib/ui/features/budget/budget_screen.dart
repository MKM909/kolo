import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/financial_calculator.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/core/widgets/domain_widgets.dart';
import 'package:kolo/ui/core/widgets/kolo_scaffold.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  _BudgetPeriod _period = _BudgetPeriod.week;

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);

    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
      data: (state) {
        final periodTransactions = _transactionsForPeriod(
          state.transactions,
          _period,
        );
        final summary = FinancialCalculator.summarize(
          balanceKobo: state.balanceKobo,
          budget: state.budgetPlan,
          transactions: periodTransactions,
          vaults: state.vaults,
        );
        final weeklyTotals = _weeklyTransactionTotals(state.transactions);
        final categoryItemCounts = _categoryExpenseCounts(periodTransactions);

        return KoloGradientScaffold(
          title: 'Budget',
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            children: [
              KoloCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _period.label,
                            key: const Key('budget_period_label'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        _BudgetPeriodToggle(
                          period: _period,
                          onChanged: (period) {
                            setState(() => _period = period);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${MoneyFormatter.formatKobo(summary.totalExpenseKobo)} spent',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 170,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 148,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    centerSpaceRadius: 45,
                                    sections: [
                                      PieChartSectionData(
                                        value: summary.totalIncomeKobo
                                            .toDouble(),
                                        color: KoloColors.primary,
                                        title: '',
                                        radius: 34,
                                      ),
                                      PieChartSectionData(
                                        value: summary.totalExpenseKobo
                                            .toDouble(),
                                        color: KoloColors.expense,
                                        title: '',
                                        radius: 34,
                                      ),
                                      PieChartSectionData(
                                        value: summary.balanceKobo <= 0
                                            ? 0
                                            : summary.balanceKobo.toDouble(),
                                        color: KoloColors.income,
                                        title: '',
                                        radius: 34,
                                      ),
                                      PieChartSectionData(
                                        value: summary.totalSavingsKobo
                                            .toDouble(),
                                        color: KoloColors.warning,
                                        title: '',
                                        radius: 34,
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Total Balance',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: KoloColors.textMuted,
                                          ),
                                    ),
                                    Text(
                                      MoneyFormatter.formatKobo(
                                        summary.balanceKobo,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'DM Mono',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _AnalyticsLegendItem(
                                  label: 'Earned',
                                  amountKobo: summary.totalIncomeKobo,
                                  color: KoloColors.primary,
                                ),
                                _AnalyticsLegendItem(
                                  label: 'Spent',
                                  amountKobo: summary.totalExpenseKobo,
                                  color: KoloColors.expense,
                                ),
                                _AnalyticsLegendItem(
                                  label: 'Available',
                                  amountKobo: summary.balanceKobo,
                                  color: KoloColors.income,
                                ),
                                _AnalyticsLegendItem(
                                  label: 'Savings',
                                  amountKobo: summary.totalSavingsKobo,
                                  color: KoloColors.warning,
                                ),
                              ],
                            ),
                          ),
                        ],
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
                      itemCount: categoryItemCounts[category.name] ?? 0,
                      onTap: () => _openCategorySheet(
                        context,
                        ref,
                        budget: state.budgetPlan,
                        category: category,
                        transactions: periodTransactions
                            .where(
                              (transaction) =>
                                  transaction.type ==
                                      TransactionType.expense &&
                                  transaction.category == category.name,
                            )
                            .toList(growable: false),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('budget_ask_kolo_replan'),
                onPressed: () {
                  context.go(
                    '/ai?prompt=${Uri.encodeQueryComponent('Redo my budget based on my current balance, savings goal, and recent spending.')}',
                  );
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Ask Kolo to re-plan'),
              ),
              const SizedBox(height: 16),
              KoloCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weekly rhythm',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      key: const Key('budget_weekly_bar_chart'),
                      height: 160,
                      child: BarChart(_weeklyBarData(weeklyTotals)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<TransactionRecord> _transactionsForPeriod(
    List<TransactionRecord> transactions,
    _BudgetPeriod period,
  ) {
    if (transactions.isEmpty) return const [];

    final anchor = _anchorDate(transactions);
    final start = period == _BudgetPeriod.week
        ? _dateOnly(anchor).subtract(const Duration(days: 6))
        : DateTime(anchor.year, anchor.month);
    final end = _dateOnly(anchor).add(const Duration(days: 1));

    return transactions
        .where(
          (transaction) =>
              !transaction.date.isBefore(start) &&
              transaction.date.isBefore(end),
        )
        .toList(growable: false);
  }

  List<_WeeklyTransactionTotals> _weeklyTransactionTotals(
    List<TransactionRecord> transactions,
  ) {
    if (transactions.isEmpty) {
      return List<_WeeklyTransactionTotals>.filled(
        7,
        const _WeeklyTransactionTotals(),
      );
    }

    final anchor = _anchorDate(transactions);
    final start = _dateOnly(anchor).subtract(const Duration(days: 6));
    final totals = List<_WeeklyTransactionTotals>.filled(
      7,
      const _WeeklyTransactionTotals(),
    );

    for (final transaction in transactions) {
      final date = _dateOnly(transaction.date);
      final index = date.difference(start).inDays;
      if (index < 0 || index >= totals.length) continue;
      totals[index] = transaction.type == TransactionType.income
          ? totals[index].copyWith(
              incomeKobo: totals[index].incomeKobo + transaction.amountKobo,
            )
          : totals[index].copyWith(
              expenseKobo: totals[index].expenseKobo + transaction.amountKobo,
            );
    }

    return totals;
  }

  Map<String, int> _categoryExpenseCounts(
    List<TransactionRecord> transactions,
  ) {
    final counts = <String, int>{};
    for (final transaction in transactions) {
      if (transaction.type != TransactionType.expense) continue;
      counts.update(
        transaction.category,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return counts;
  }

  BarChartData _weeklyBarData(List<_WeeklyTransactionTotals> totals) {
    final maxKobo = totals.fold<int>(
      0,
      (max, value) {
        final dayMax = value.incomeKobo > value.expenseKobo
            ? value.incomeKobo
            : value.expenseKobo;
        return dayMax > max ? dayMax : max;
      },
    );
    final maxY = maxKobo == 0 ? 1.0 : maxKobo * 1.2;

    return BarChartData(
      maxY: maxY,
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: Color(0x20000000), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              final index = value.toInt();
              if (index < 0 || index >= labels.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  labels[index],
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: KoloColors.textMuted),
                ),
              );
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(enabled: false),
      barGroups: [
        for (var index = 0; index < totals.length; index++)
          BarChartGroupData(
            x: index,
            barsSpace: 3,
            barRods: [
              BarChartRodData(
                toY: totals[index].incomeKobo.toDouble(),
                width: 8,
                color: KoloColors.primary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
              BarChartRodData(
                toY: totals[index].expenseKobo.toDouble(),
                width: 8,
                color: KoloColors.expense,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          ),
      ],
    );
  }

  DateTime _anchorDate(List<TransactionRecord> transactions) {
    return transactions
        .map((transaction) => transaction.date)
        .reduce((latest, date) => date.isAfter(latest) ? date : latest);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  Future<void> _openCategorySheet(
    BuildContext context,
    WidgetRef ref, {
    required BudgetPlan budget,
    required BudgetCategory category,
    required List<TransactionRecord> transactions,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BudgetCategorySheet(
        budget: budget,
        category: category,
        transactions: transactions,
        ref: ref,
      ),
    );
  }
}

class _WeeklyTransactionTotals {
  const _WeeklyTransactionTotals({this.incomeKobo = 0, this.expenseKobo = 0});

  final int incomeKobo;
  final int expenseKobo;

  _WeeklyTransactionTotals copyWith({int? incomeKobo, int? expenseKobo}) {
    return _WeeklyTransactionTotals(
      incomeKobo: incomeKobo ?? this.incomeKobo,
      expenseKobo: expenseKobo ?? this.expenseKobo,
    );
  }
}

class _AnalyticsLegendItem extends StatelessWidget {
  const _AnalyticsLegendItem({
    required this.label,
    required this.amountKobo,
    required this.color,
  });

  final String label;
  final int amountKobo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            height: 8,
            width: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Flexible(
            child: Text(
              MoneyFormatter.formatKobo(amountKobo),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: 'DM Mono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _BudgetPeriod {
  week('This Week'),
  month('This Month');

  const _BudgetPeriod(this.label);

  final String label;
}

class _BudgetPeriodToggle extends StatelessWidget {
  const _BudgetPeriodToggle({required this.period, required this.onChanged});

  final _BudgetPeriod period;
  final ValueChanged<_BudgetPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 168,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: KoloColors.surfaceWhite,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: KoloColors.primaryPastel),
      ),
      child: Row(
        children: [
          _BudgetPeriodOption(
            key: const Key('budget_period_week'),
            label: 'Week',
            selected: period == _BudgetPeriod.week,
            onTap: () => onChanged(_BudgetPeriod.week),
          ),
          _BudgetPeriodOption(
            key: const Key('budget_period_month'),
            label: 'Month',
            selected: period == _BudgetPeriod.month,
            onTap: () => onChanged(_BudgetPeriod.month),
          ),
        ],
      ),
    );
  }
}

class _BudgetPeriodOption extends StatelessWidget {
  const _BudgetPeriodOption({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? KoloColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : KoloColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetCategorySheet extends StatefulWidget {
  const _BudgetCategorySheet({
    required this.budget,
    required this.category,
    required this.transactions,
    required this.ref,
  });

  final BudgetPlan budget;
  final BudgetCategory category;
  final List<TransactionRecord> transactions;
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
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
        child: SingleChildScrollView(
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: KoloColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              _CategoryTransactionBreakdown(
                transactions: widget.transactions,
              ),
              const SizedBox(height: 18),
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
                Text(
                  _error!,
                  style: const TextStyle(color: KoloColors.expense),
                ),
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

class _CategoryTransactionBreakdown extends StatelessWidget {
  const _CategoryTransactionBreakdown({required this.transactions});

  final List<TransactionRecord> transactions;

  @override
  Widget build(BuildContext context) {
    final totalKobo = transactions.fold<int>(
      0,
      (total, transaction) => total + transaction.amountKobo,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent transactions',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              MoneyFormatter.formatKobo(totalKobo),
              style: const TextStyle(
                fontFamily: 'DM Mono',
                fontWeight: FontWeight.w800,
                color: KoloColors.expense,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (transactions.isEmpty)
          Text(
            'No spending in this period.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: KoloColors.textSecondary),
          )
        else
          for (final transaction in transactions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CategoryTransactionRow(transaction: transaction),
            ),
      ],
    );
  }
}

class _CategoryTransactionRow extends StatelessWidget {
  const _CategoryTransactionRow({required this.transaction});

  final TransactionRecord transaction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: KoloColors.primaryPastel,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.receipt_long_outlined,
            color: KoloColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                _dateInput(transaction.date),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: KoloColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '-${MoneyFormatter.formatKobo(transaction.amountKobo)}',
          style: const TextStyle(
            fontFamily: 'DM Mono',
            fontWeight: FontWeight.w800,
            color: KoloColors.expense,
          ),
        ),
      ],
    );
  }
}

String _dateInput(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
