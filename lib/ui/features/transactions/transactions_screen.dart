import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/core/widgets/domain_widgets.dart';
import 'package:kolo/ui/core/widgets/kolo_scaffold.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
      data: (state) => KoloGradientScaffold(
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
            KoloCard(
              child: Column(
                children: [
                  for (final tx in state.transactions)
                    TransactionTile(transaction: tx),
                ],
              ),
            ),
          ],
        ),
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
