import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/core/widgets/domain_widgets.dart';
import 'package:kolo/ui/core/widgets/kolo_scaffold.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  _TransactionFilter _filter = _TransactionFilter.all;

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);

    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
      data: (state) {
        final filteredTransactions = _filter.apply(state.transactions);
        return KoloGradientScaffold(
          title: 'Transactions',
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            children: [
              KoloCard(
                child: Row(
                  children: [
                    _Metric(
                      label: 'Income',
                      amountKobo: state.transactions
                          .where((tx) => tx.type == TransactionType.income)
                          .fold(0, (total, tx) => total + tx.amountKobo),
                      color: KoloColors.income,
                    ),
                    const SizedBox(width: 16),
                    _Metric(
                      label: 'Expense',
                      amountKobo: state.transactions
                          .where((tx) => tx.type == TransactionType.expense)
                          .fold(0, (total, tx) => total + tx.amountKobo),
                      color: KoloColors.expense,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const KoloSectionHeader(title: 'History'),
              const SizedBox(height: 8),
              _TransactionFilterPill(
                selected: _filter,
                onChanged: (filter) => setState(() => _filter = filter),
              ),
              const SizedBox(height: 14),
              KoloCard(
                child: Column(
                  children: [
                    for (final tx in filteredTransactions)
                      TransactionTile(
                        transaction: tx,
                        onTap: () => _openTransactionDetail(context, tx),
                      ),
                    if (filteredTransactions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          'No transactions here yet.',
                          style: TextStyle(color: KoloColors.textSecondary),
                        ),
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

  Future<void> _openTransactionDetail(
    BuildContext context,
    TransactionRecord transaction,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TransactionDetailSheet(transaction: transaction),
    );
  }
}

enum _TransactionFilter {
  all(label: 'All', keyName: 'all'),
  income(label: 'Income', keyName: 'income'),
  expense(label: 'Expense', keyName: 'expense');

  const _TransactionFilter({required this.label, required this.keyName});

  final String label;
  final String keyName;

  List<TransactionRecord> apply(List<TransactionRecord> transactions) {
    return switch (this) {
      _TransactionFilter.all => transactions,
      _TransactionFilter.income =>
        transactions.where((tx) => tx.type == TransactionType.income).toList(),
      _TransactionFilter.expense =>
        transactions.where((tx) => tx.type == TransactionType.expense).toList(),
    };
  }
}

class _TransactionFilterPill extends StatelessWidget {
  const _TransactionFilterPill({
    required this.selected,
    required this.onChanged,
  });

  final _TransactionFilter selected;
  final ValueChanged<_TransactionFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final filter in _TransactionFilter.values)
            Expanded(
              child: InkWell(
                key: Key('transaction_filter_${filter.keyName}'),
                borderRadius: BorderRadius.circular(999),
                onTap: () => onChanged(filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == filter
                        ? KoloColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    filter.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected == filter
                          ? Colors.white
                          : KoloColors.textSecondary,
                      fontWeight: selected == filter
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.amountKobo,
    required this.color,
  });

  final String label;
  final int amountKobo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            MoneyFormatter.formatKobo(amountKobo),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

const _transactionCategoryOptions = [
  'Food & Snacks',
  'Transport',
  'Data & Airtime',
  'Entertainment',
  'Utilities & Bills',
  'Gig Income',
  'Family/Gift Income',
  'Savings',
  'Miscellaneous',
];

class _TransactionDetailSheet extends ConsumerStatefulWidget {
  const _TransactionDetailSheet({required this.transaction});

  final TransactionRecord transaction;

  @override
  ConsumerState<_TransactionDetailSheet> createState() =>
      _TransactionDetailSheetState();
}

class _TransactionDetailSheetState
    extends ConsumerState<_TransactionDetailSheet> {
  late String _category;
  String? _error;

  @override
  void initState() {
    super.initState();
    _category = widget.transaction.category;
  }

  List<String> get _categoryOptions {
    if (_transactionCategoryOptions.contains(widget.transaction.category)) {
      return _transactionCategoryOptions;
    }
    return [widget.transaction.category, ..._transactionCategoryOptions];
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final isIncome = transaction.type == TransactionType.income;
    final signedAmount =
        '${isIncome ? '+' : '-'}${MoneyFormatter.formatKobo(transaction.amountKobo)}';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        key: const Key('transaction_detail_sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
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
        child: SafeArea(
          top: false,
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
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: KoloColors.primaryPastel,
                      child: Text(isIncome ? '+' : _emojiFor(_category)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.description,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            transaction.merchantName ?? transaction.category,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      signedAmount,
                      style: TextStyle(
                        color: isIncome
                            ? KoloColors.income
                            : KoloColors.expense,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _DetailRow(label: 'Category', value: transaction.category),
                _DetailRow(label: 'Source', value: transaction.source.name),
                _DetailRow(label: 'Type', value: transaction.type.name),
                _DetailRow(label: 'Date', value: _dateInput(transaction.date)),
                const SizedBox(height: 12),
                Text(
                  'Correct category',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: const Key('transaction_category_dropdown'),
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final category in _categoryOptions)
                      DropdownMenuItem(value: category, child: Text(category)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _category = value;
                      _error = null;
                    });
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: KoloColors.expense),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('save_transaction_category'),
                  onPressed: _category == transaction.category
                      ? null
                      : _saveCategory,
                  icon: const Icon(Icons.category_outlined),
                  label: const Text('Save category'),
                ),
                if (transaction.aiNote != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: KoloColors.primaryPastel,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      transaction.aiNote!,
                      style: const TextStyle(
                        color: KoloColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveCategory() async {
    try {
      await ref
          .read(koloRepositoryProvider)
          .updateTransactionCategory(
            transactionId: widget.transaction.id,
            category: _category,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save that category. Try again.';
      });
    }
  }

  String _emojiFor(String category) {
    if (category.contains('Food')) return 'ðŸœ';
    if (category.contains('Transport')) return 'ðŸšŒ';
    if (category.contains('Data')) return 'ðŸ“¶';
    if (category.contains('Gig')) return 'ðŸ’¼';
    return 'â€¢';
  }
}

String _dateInput(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
