import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';

class BalanceAdjustmentSheet extends ConsumerStatefulWidget {
  const BalanceAdjustmentSheet({required this.currentBalanceKobo, super.key});

  final int currentBalanceKobo;

  @override
  ConsumerState<BalanceAdjustmentSheet> createState() =>
      _BalanceAdjustmentSheetState();
}

class _BalanceAdjustmentSheetState
    extends ConsumerState<BalanceAdjustmentSheet> {
  late final TextEditingController _amountController;
  final TextEditingController _noteController = TextEditingController(
    text: 'Matched bank app',
  );
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: (widget.currentBalanceKobo / 100).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        key: const Key('balance_adjustment_sheet'),
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
              'Adjust balance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Use this when your bank app and Kolo disagree.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: KoloColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('balance_adjustment_amount'),
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Current balance',
                prefixText: '\u20A6 ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('balance_adjustment_note'),
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: KoloColors.expense)),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              key: const Key('save_balance_adjustment'),
              onPressed: _save,
              child: const Text('Save balance'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final newBalanceKobo = MoneyFormatter.parseNairaToKobo(
      _amountController.text.trim(),
    );
    if (newBalanceKobo == null || newBalanceKobo < 0) {
      setState(() => _error = 'Enter a valid balance.');
      return;
    }

    final note = _noteController.text.trim();
    final now = DateTime.now();
    await ref
        .read(koloRepositoryProvider)
        .adjustBalance(
          BalanceAdjustment(
            id: 'balance-${now.microsecondsSinceEpoch}',
            previousBalanceKobo: widget.currentBalanceKobo,
            newBalanceKobo: newBalanceKobo,
            note: note.isEmpty ? 'Manual balance correction' : note,
            createdAt: now,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }
}
