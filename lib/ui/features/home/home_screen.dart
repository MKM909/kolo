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
                onAdjust: () => _openBalanceAdjustmentSheet(
                  context,
                  ref,
                  currentBalanceKobo: state.balanceKobo,
                ),
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
                onOpenVaults: () => _openVaultsSheet(context),
                onOpenOwings: () => _openOwingsSheet(context),
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
              KoloSectionHeader(
                title: 'Budget Summary',
                action: 'View',
                actionKey: const Key('home_budget_summary_view'),
                onAction: () => context.go('/budget'),
              ),
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
              KoloSectionHeader(
                title: 'Recent Transactions',
                action: 'View All',
                actionKey: const Key('home_recent_transactions_view_all'),
                onAction: () => context.go('/transactions'),
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

  Future<void> _openBalanceAdjustmentSheet(
    BuildContext context,
    WidgetRef ref, {
    required int currentBalanceKobo,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BalanceAdjustmentSheet(
        currentBalanceKobo: currentBalanceKobo,
        ref: ref,
      ),
    );
  }

  Future<void> _openVaultsSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _VaultsSheet(),
    );
  }

  Future<void> _openOwingsSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _OwingsSheet(),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onLogIncome,
    required this.onLogExpense,
    required this.onOpenVaults,
    required this.onOpenOwings,
  });

  final VoidCallback onLogIncome;
  final VoidCallback onLogExpense;
  final VoidCallback onOpenVaults;
  final VoidCallback onOpenOwings;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.add_circle_outline, 'Log Income', onLogIncome),
      (Icons.remove_circle_outline, 'Log Expense', onLogExpense),
      (Icons.lock_outline, 'Vaults', onOpenVaults),
      (Icons.handshake_outlined, 'Owings', onOpenOwings),
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

class _BalanceAdjustmentSheet extends StatefulWidget {
  const _BalanceAdjustmentSheet({
    required this.currentBalanceKobo,
    required this.ref,
  });

  final int currentBalanceKobo;
  final WidgetRef ref;

  @override
  State<_BalanceAdjustmentSheet> createState() =>
      _BalanceAdjustmentSheetState();
}

class _BalanceAdjustmentSheetState extends State<_BalanceAdjustmentSheet> {
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
    await widget.ref
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

class _VaultsSheet extends ConsumerStatefulWidget {
  const _VaultsSheet();

  @override
  ConsumerState<_VaultsSheet> createState() => _VaultsSheetState();
}

class _VaultsSheetState extends ConsumerState<_VaultsSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        key: const Key('vaults_sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
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
                Text(
                  'Savings Vaults',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Protect money for goals without moving it anywhere.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: KoloColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                dashboard.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text('Could not load vaults: $error'),
                  data: (state) => Column(
                    children: [
                      for (final vault in state.vaults)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _VaultCard(
                            vault: vault,
                            onTap: () => _openVaultDetail(context, vault),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'New vault',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('new_vault_name'),
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Vault name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('new_vault_target'),
                  controller: _targetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target amount',
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
                  key: const Key('save_new_vault'),
                  onPressed: _save,
                  child: const Text('Create vault'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final targetKobo = MoneyFormatter.parseNairaToKobo(
      _targetController.text.trim(),
    );
    if (name.isEmpty || targetKobo == null || targetKobo <= 0) {
      setState(() => _error = 'Enter a vault name and target.');
      return;
    }

    await ref
        .read(koloRepositoryProvider)
        .upsertVault(
          SavingsVault(
            id: 'vault-${DateTime.now().microsecondsSinceEpoch}',
            name: name,
            targetKobo: targetKobo,
            currentKobo: 0,
          ),
        );
    _nameController.clear();
    _targetController.clear();
    if (mounted) setState(() => _error = null);
  }

  Future<void> _openVaultDetail(BuildContext context, SavingsVault vault) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VaultDetailSheet(vault: vault),
    );
  }
}

class _VaultCard extends StatelessWidget {
  const _VaultCard({required this.vault, required this.onTap});

  final SavingsVault vault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 20),
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
                  child: const Icon(
                    Icons.lock_outline,
                    color: KoloColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    vault.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  MoneyFormatter.formatKobo(vault.targetKobo),
                  style: const TextStyle(
                    color: KoloColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: vault.progress,
                minHeight: 8,
                backgroundColor: KoloColors.primaryPastel,
                color: KoloColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${MoneyFormatter.formatKobo(vault.currentKobo)} saved',
              style: const TextStyle(
                color: KoloColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultDetailSheet extends ConsumerStatefulWidget {
  const _VaultDetailSheet({required this.vault});

  final SavingsVault vault;

  @override
  ConsumerState<_VaultDetailSheet> createState() => _VaultDetailSheetState();
}

class _VaultDetailSheetState extends ConsumerState<_VaultDetailSheet> {
  final TextEditingController _amountController = TextEditingController();
  String? _error;

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
        key: const Key('vault_detail_sheet'),
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
                widget.vault.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${MoneyFormatter.formatKobo(widget.vault.currentKobo)} / ${MoneyFormatter.formatKobo(widget.vault.targetKobo)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: widget.vault.progress,
                        minHeight: 8,
                        backgroundColor: KoloColors.primaryPastel,
                        color: KoloColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('vault_contribution_amount'),
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Add funds',
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
                key: const Key('save_vault_contribution'),
                onPressed: _save,
                child: const Text('Add to vault'),
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
      setState(() => _error = 'Enter a valid amount.');
      return;
    }

    await ref
        .read(koloRepositoryProvider)
        .upsertVault(
          SavingsVault(
            id: widget.vault.id,
            name: widget.vault.name,
            targetKobo: widget.vault.targetKobo,
            currentKobo: widget.vault.currentKobo + amountKobo,
            deadline: widget.vault.deadline,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }
}

class _OwingsSheet extends ConsumerStatefulWidget {
  const _OwingsSheet();

  @override
  ConsumerState<_OwingsSheet> createState() => _OwingsSheetState();
}

class _OwingsSheetState extends ConsumerState<_OwingsSheet> {
  final TextEditingController _personController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  OwingType _type = OwingType.theyOweMe;
  String? _error;

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        key: const Key('owings_sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
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
                Text('Owings', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'Track who owes you and what you owe, without awkward memory math.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: KoloColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                dashboard.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text('Could not load owings: $error'),
                  data: (state) => Column(
                    children: [
                      for (final owing in state.owings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _OwingCard(
                            owing: owing,
                            onTap: () => _openOwingDetail(context, owing),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'New owing',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SegmentedButton<OwingType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: OwingType.theyOweMe,
                      label: Text('They owe me'),
                    ),
                    ButtonSegment(
                      value: OwingType.iOweThem,
                      label: Text('I owe them'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (selected) {
                    setState(() => _type = selected.single);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('new_owing_person'),
                  controller: _personController,
                  decoration: const InputDecoration(labelText: 'Person'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('new_owing_amount'),
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\u20A6 ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: 'Note'),
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
                  key: const Key('save_new_owing'),
                  onPressed: _save,
                  child: const Text('Save owing'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final person = _personController.text.trim();
    final amountKobo = MoneyFormatter.parseNairaToKobo(
      _amountController.text.trim(),
    );
    if (person.isEmpty || amountKobo == null || amountKobo <= 0) {
      setState(() => _error = 'Enter a person and amount.');
      return;
    }

    final now = DateTime.now();
    await ref
        .read(koloRepositoryProvider)
        .upsertOwing(
          Owing(
            id: 'owing-${now.microsecondsSinceEpoch}',
            type: _type,
            person: person,
            amountKobo: amountKobo,
            date: now,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          ),
        );
    _personController.clear();
    _amountController.clear();
    _noteController.clear();
    if (mounted) setState(() => _error = null);
  }

  Future<void> _openOwingDetail(BuildContext context, Owing owing) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OwingDetailSheet(owing: owing),
    );
  }
}

class _OwingCard extends StatelessWidget {
  const _OwingCard({required this.owing, required this.onTap});

  final Owing owing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theyOweMe = owing.type == OwingType.theyOweMe;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 20),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: KoloColors.primaryPastel,
              child: Text(
                owing.person.isEmpty ? '?' : owing.person.characters.first,
                style: const TextStyle(
                  color: KoloColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    owing.person,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    owing.settled
                        ? 'Settled'
                        : theyOweMe
                        ? 'They owe you'
                        : 'You owe them',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            Text(
              MoneyFormatter.formatKobo(owing.amountKobo),
              style: TextStyle(
                color: theyOweMe ? KoloColors.income : KoloColors.expense,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwingDetailSheet extends ConsumerStatefulWidget {
  const _OwingDetailSheet({required this.owing});

  final Owing owing;

  @override
  ConsumerState<_OwingDetailSheet> createState() => _OwingDetailSheetState();
}

class _OwingDetailSheetState extends ConsumerState<_OwingDetailSheet> {
  String? _draft;
  bool _drafting = false;

  @override
  Widget build(BuildContext context) {
    final owing = widget.owing;
    final theyOweMe = owing.type == OwingType.theyOweMe;
    return Container(
      key: const Key('owing_detail_sheet'),
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
            Text(owing.person, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _OwingDetailRow(
              label: theyOweMe ? 'They owe you' : 'You owe them',
              value: MoneyFormatter.formatKobo(owing.amountKobo),
              color: theyOweMe ? KoloColors.income : KoloColors.expense,
            ),
            if (owing.note != null)
              _OwingDetailRow(label: 'Note', value: owing.note!),
            _OwingDetailRow(
              label: 'Status',
              value: owing.settled ? 'Settled' : 'Open',
            ),
            if (theyOweMe && !owing.settled) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                key: const Key('draft_owing_reminder'),
                onPressed: _drafting ? null : _draftReminder,
                icon: _drafting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_drafting ? 'Drafting...' : 'Draft reminder'),
              ),
            ],
            if (_draft != null) ...[
              const SizedBox(height: 12),
              Container(
                key: const Key('owing_reminder_draft'),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Color(0x14000000), blurRadius: 20),
                  ],
                ),
                child: Text(
                  _draft!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              key: const Key('settle_owing'),
              onPressed: owing.settled
                  ? null
                  : () async {
                      await ref
                          .read(koloRepositoryProvider)
                          .upsertOwing(
                            Owing(
                              id: owing.id,
                              type: owing.type,
                              person: owing.person,
                              amountKobo: owing.amountKobo,
                              date: owing.date,
                              settled: true,
                              note: owing.note,
                              dueDate: owing.dueDate,
                            ),
                          );
                      if (context.mounted) Navigator.of(context).pop();
                    },
              child: const Text('Mark settled'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _draftReminder() async {
    setState(() => _drafting = true);
    final draft = await ref
        .read(koloRepositoryProvider)
        .draftOwingReminder(widget.owing);
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _drafting = false;
    });
  }
}

class _OwingDetailRow extends StatelessWidget {
  const _OwingDetailRow({
    required this.label,
    required this.value,
    this.color = KoloColors.textPrimary,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const Spacer(),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
