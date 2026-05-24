import 'package:flutter/material.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    required this.balanceKobo,
    required this.name,
    this.onAdjust,
    super.key,
  });

  final int balanceKobo;
  final String name;
  final VoidCallback? onAdjust;

  @override
  Widget build(BuildContext context) {
    final isNegative = balanceKobo < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: KoloColors.surfaceDark,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              height: 120,
              width: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x207C3AED),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.white),
                  Spacer(),
                  Text(
                    'Kolo Wallet',
                    style: TextStyle(color: KoloColors.textOnDarkMuted),
                  ),
                ],
              ),
              const SizedBox(height: 42),
              const Text(
                'Balance',
                style: TextStyle(color: KoloColors.textOnDarkMuted),
              ),
              Text(
                MoneyFormatter.formatKobo(balanceKobo),
                style: TextStyle(
                  fontFamily: 'DM Mono',
                  color: isNegative ? KoloColors.expense : Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (isNegative) ...[
                const SizedBox(height: 10),
                Container(
                  key: const Key('balance_negative_warning'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: KoloColors.expense.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: KoloColors.expense.withValues(alpha: 0.36),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: KoloColors.expense,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "Balance is in the red. Let's talk before spending.",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    name.toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Spacer(),
                  InkWell(
                    key: const Key('balance_adjust_button'),
                    borderRadius: BorderRadius.circular(999),
                    onTap: onAdjust,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Adjust',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({required this.transaction, this.onTap, super.key});

  final TransactionRecord transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: KoloColors.primaryPastel,
              child: Text(isIncome ? '+' : _emojiFor(transaction.category)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    transaction.category,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            Text(
              '${isIncome ? '+' : '-'}${MoneyFormatter.formatKobo(transaction.amountKobo)}',
              style: TextStyle(
                color: isIncome ? KoloColors.income : KoloColors.expense,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emojiFor(String category) {
    if (category.contains('Food')) return '🍜';
    if (category.contains('Transport')) return '🚌';
    if (category.contains('Data')) return '📶';
    if (category.contains('Gig')) return '💼';
    return '•';
  }
}

class BudgetCategoryCard extends StatelessWidget {
  const BudgetCategoryCard({
    required this.category,
    required this.spentKobo,
    required this.itemCount,
    this.onTap,
    super.key,
  });

  final BudgetCategory category;
  final int spentKobo;
  final int itemCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress = category.allocatedKobo == 0
        ? 0.0
        : (spentKobo / category.allocatedKobo).clamp(0, 1).toDouble();
    final color = progress > 0.9
        ? KoloColors.expense
        : progress > 0.7
        ? KoloColors.warning
        : KoloColors.primary;

    return InkWell(
      key: Key('budget_category_${category.name}'),
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x10000000), blurRadius: 16),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 36,
                  width: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: KoloColors.primaryPastel,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(category.emoji),
                ),
                const Spacer(),
                Text(
                  itemCount == 1 ? '1 item' : '$itemCount items',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: KoloColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${MoneyFormatter.formatKobo(spentKobo)} / ${MoneyFormatter.formatKobo(category.allocatedKobo)}',
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: KoloColors.primaryPastel,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
