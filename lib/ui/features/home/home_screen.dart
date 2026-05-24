import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/financial_calculator.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/core/widgets/domain_widgets.dart';
import 'package:kolo/ui/core/widgets/kolo_scaffold.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return dashboard.when(
      loading: () => const KoloGradientScaffold(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => KoloGradientScaffold(
        child: Center(child: Text('Kolo is offline: $error')),
      ),
      data: (state) {
        final summary = FinancialCalculator.summarize(
          balanceKobo: state.balanceKobo,
          budget: state.budgetPlan,
          transactions: state.transactions,
          vaults: state.vaults,
        );

        return KoloGradientScaffold(
          title: 'Kolo',
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.notifications_none),
              ),
            ),
          ],
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            children: [
              BalanceCard(
                balanceKobo: state.balanceKobo,
                name: state.profile.name,
              ),
              const SizedBox(height: 20),
              _QuickActions(
                onLogIncome: () => _openTransactionSheet(
                  context,
                  ref,
                  type: TransactionType.income,
                ),
                onLogExpense: () => _openTransactionSheet(
                  context,
                  ref,
                  type: TransactionType.expense,
                ),
              ),
              const SizedBox(height: 24),
              if (state.bills.isNotEmpty)
                KoloCard(
                  color: KoloColors.surfaceElevated,
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, color: KoloColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${state.bills.first.name} is due soon: ${MoneyFormatter.formatKobo(state.bills.first.amountKobo)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              const KoloSectionHeader(title: 'Budget Summary', action: 'View'),
              KoloCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${MoneyFormatter.formatKobo(summary.totalExpenseKobo)} spent of ${MoneyFormatter.formatKobo(state.budgetPlan.totalAllocatedKobo)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value:
                            (summary.totalExpenseKobo /
                                    state.budgetPlan.totalAllocatedKobo)
                                .clamp(0, 1)
                                .toDouble(),
                        minHeight: 8,
                        color: KoloColors.primary,
                        backgroundColor: KoloColors.primaryPastel,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const KoloSectionHeader(
                title: 'Recent Transactions',
                action: 'View All',
              ),
              KoloCard(
                child: Column(
                  children: [
                    for (final tx in state.transactions.take(3))
                      TransactionTile(transaction: tx),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const KoloSectionHeader(title: 'Kolo Insights'),
              for (final insight in state.insights)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: KoloCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(insight.body),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openTransactionSheet(
    BuildContext context,
    WidgetRef ref, {
    required TransactionType type,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TransactionEntrySheet(type: type, ref: ref),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onLogIncome, required this.onLogExpense});

  final VoidCallback onLogIncome;
  final VoidCallback onLogExpense;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.add_circle_outline, 'Log Income', onLogIncome),
      (Icons.remove_circle_outline, 'Log Expense', onLogExpense),
      (Icons.lock_outline, 'Vaults', () {}),
      (Icons.handshake_outlined, 'Owings', () {}),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final action in actions)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: action.$3,
              child: Column(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Color(0x12000000), blurRadius: 14),
                      ],
                    ),
                    child: Icon(action.$1, color: KoloColors.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    action.$2,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TransactionEntrySheet extends StatefulWidget {
  const _TransactionEntrySheet({required this.type, required this.ref});

  final TransactionType type;
  final WidgetRef ref;

  @override
  State<_TransactionEntrySheet> createState() => _TransactionEntrySheetState();
}

class _TransactionEntrySheetState extends State<_TransactionEntrySheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _category = 'Food & Snacks';
  String? _error;

  bool get _isIncome => widget.type == TransactionType.income;

  @override
  void initState() {
    super.initState();
    _category = _isIncome ? 'Gig Income' : 'Food & Snacks';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              _isIncome ? 'Log Income' : 'Log Expense',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('transaction_amount'),
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₦ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('transaction_description'),
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: [
                for (final category
                    in _isIncome
                        ? const [
                            'Gig Income',
                            'Family/Gift Income',
                            'Miscellaneous',
                          ]
                        : const [
                            'Food & Snacks',
                            'Transport',
                            'Data & Airtime',
                            'Entertainment',
                            'Utilities & Bills',
                            'Miscellaneous',
                          ])
                  DropdownMenuItem(value: category, child: Text(category)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _category = value);
              },
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: KoloColors.expense)),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              key: const Key('save_transaction'),
              onPressed: _save,
              child: Text(_isIncome ? 'Save income' : 'Save expense'),
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
    final description = _descriptionController.text.trim();
    if (amountKobo == null || amountKobo <= 0 || description.isEmpty) {
      setState(() => _error = 'Enter an amount and description.');
      return;
    }

    final id = 'manual-${DateTime.now().microsecondsSinceEpoch}';
    final transaction = _isIncome
        ? TransactionRecord.income(
            id: id,
            amountKobo: amountKobo,
            category: _category,
            description: description,
            date: DateTime.now(),
            source: TransactionSource.manual,
          )
        : TransactionRecord.expense(
            id: id,
            amountKobo: amountKobo,
            category: _category,
            description: description,
            date: DateTime.now(),
            source: TransactionSource.manual,
          );

    await widget.ref.read(koloRepositoryProvider).logTransaction(transaction);
    if (mounted) Navigator.of(context).pop();
  }
}
