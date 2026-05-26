import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/data/services/offline_sync_queue.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/bill_protection_advisor.dart';
import 'package:kolo/domain/services/bill_reminder_schedule.dart';
import 'package:kolo/domain/services/financial_calculator.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/domain/services/vault_protection_advisor.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/core/widgets/balance_adjustment_sheet.dart';
import 'package:kolo/ui/core/widgets/domain_widgets.dart';
import 'package:kolo/ui/core/widgets/kolo_scaffold.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final syncState = ref.watch(pendingSyncOperationsProvider);

    return dashboard.when(
      loading: () => const KoloGradientScaffold(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const _HomeOfflineState(),
      data: (state) {
        final summary = FinancialCalculator.summarize(
          balanceKobo: state.balanceKobo,
          budget: state.budgetPlan,
          transactions: state.transactions,
          vaults: state.vaults,
        );
        final dueSoonBill = _nearestDueSoonBill(state.bills);
        final netOwingsKobo = _netUnsettledOwingsKobo(state.owings);

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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  BalanceCard(
                    balanceKobo: state.balanceKobo,
                    name: state.profile.name,
                    onAdjust: () => _openBalanceAdjustmentSheet(
                      context,
                      currentBalanceKobo: state.balanceKobo,
                    ),
                  ),
                  Positioned(
                    right: 14,
                    bottom: -18,
                    child: _HomeSyncStatusPill(syncState: syncState),
                  ),
                ],
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
              if (netOwingsKobo != 0) ...[
                _NetOwingsSummaryCard(netKobo: netOwingsKobo),
                const SizedBox(height: 24),
              ],
              if (dueSoonBill != null)
                KoloCard(
                  color: KoloColors.surfaceElevated,
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, color: KoloColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${dueSoonBill.name} is due soon: ${MoneyFormatter.formatKobo(dueSoonBill.amountKobo)}',
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
              KoloSectionHeader(
                title: 'Kolo Insights',
                action: 'Refresh',
                actionKey: const Key('generate_weekly_insight'),
                onAction: () {
                  ref.read(koloRepositoryProvider).generateWeeklyInsight();
                },
              ),
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
    BuildContext context, {
    required int currentBalanceKobo,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          BalanceAdjustmentSheet(currentBalanceKobo: currentBalanceKobo),
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

int _netUnsettledOwingsKobo(List<Owing> owings) {
  return owings.where((owing) => !owing.settled).fold<int>(0, (total, owing) {
    return total +
        (owing.type == OwingType.theyOweMe
            ? owing.amountKobo
            : -owing.amountKobo);
  });
}

class _NetOwingsSummaryCard extends StatelessWidget {
  const _NetOwingsSummaryCard({required this.netKobo});

  final int netKobo;

  @override
  Widget build(BuildContext context) {
    final positive = netKobo > 0;
    return KoloCard(
      child: Row(
        key: const Key('home_net_owings_summary'),
        children: [
          Container(
            height: 40,
            width: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KoloColors.primaryPastel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.handshake_outlined,
              color: positive ? KoloColors.income : KoloColors.expense,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  positive ? 'Net owed to you' : 'Net you owe',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unsettled owings',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: KoloColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            MoneyFormatter.formatKobo(netKobo.abs()),
            style: TextStyle(
              color: positive ? KoloColors.income : KoloColors.expense,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

BillReminder? _nearestDueSoonBill(List<BillReminder> bills) {
  final dueSoonBills = BillReminderSchedule.dueSoon(bills).toList()
    ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
  return dueSoonBills.isEmpty ? null : dueSoonBills.first;
}

class _HomeOfflineState extends StatelessWidget {
  const _HomeOfflineState();

  @override
  Widget build(BuildContext context) {
    return KoloGradientScaffold(
      title: 'Kolo',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: KoloCard(
            key: const Key('home_offline_state'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: KoloColors.primaryPastel,
                  child: Icon(
                    Icons.cloud_off_outlined,
                    color: KoloColors.primary,
                    size: 30,
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  'Kolo is offline',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: KoloColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your money view will use local cache when it is available. Sync, Gemini updates, and fresh transactions resume when the connection returns.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: KoloColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeSyncStatusPill extends StatelessWidget {
  const _HomeSyncStatusPill({required this.syncState});

  final AsyncValue<List<PendingSyncOperation>> syncState;

  @override
  Widget build(BuildContext context) {
    final operations = syncState.value ?? const <PendingSyncOperation>[];
    final hasPending = operations.isNotEmpty;
    final hasError = syncState.hasError && !syncState.hasValue;
    final statusColor = hasError
        ? KoloColors.warning
        : hasPending
        ? KoloColors.warning
        : KoloColors.income;
    final title = hasError
        ? 'Sync paused'
        : hasPending
        ? 'Waiting to sync'
        : syncState.isLoading
        ? 'Checking sync'
        : 'All synced';
    final countLabel = hasError
        ? 'Retry soon'
        : hasPending
        ? '${operations.length} pending'
        : syncState.isLoading
        ? 'Checking'
        : 'Clear';

    return Container(
      key: const Key('home_sync_status'),
      constraints: const BoxConstraints(maxWidth: 174),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_sync_outlined, color: statusColor, size: 17),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: KoloColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  countLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
  late final TextEditingController _dateController;
  final TextEditingController _justificationController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _category = 'Food & Snacks';
  String? _error;
  bool _needsJustification = false;
  bool _evaluatingJustification = false;
  SpendingJustificationDecision? _spendingDecision;
  int? _pendingAmountKobo;
  String? _pendingDescription;
  DateTime? _pendingDate;

  bool get _isIncome => widget.type == TransactionType.income;

  @override
  void initState() {
    super.initState();
    _category = _isIncome ? 'Gig Income' : 'Food & Snacks';
    _dateController = TextEditingController(text: _dateInput(DateTime.now()));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _justificationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
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
              TextField(
                key: const Key('transaction_date'),
                controller: _dateController,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  hintText: 'YYYY-MM-DD',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
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
              if (_needsJustification) ...[
                const SizedBox(height: 14),
                Container(
                  key: const Key('spending_justification_prompt'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: KoloColors.primaryPastel,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: KoloColors.primary,
                        child: Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _justificationPromptText(),
                          style: const TextStyle(
                            color: KoloColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('spending_justification_field'),
                  controller: _justificationController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    prefixIcon: Icon(Icons.chat_bubble_outline),
                  ),
                ),
                if (_spendingDecision != null) ...[
                  const SizedBox(height: 12),
                  _SpendingDecisionCard(
                    decision: _spendingDecision!,
                    onCancel: () => Navigator.of(context).pop(),
                    onLog: () => _logDecidedExpense(overrideDecision: false),
                    onOverride: () =>
                        _logDecidedExpense(overrideDecision: true),
                  ),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: KoloColors.expense),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                key: _needsJustification
                    ? const Key('save_spending_justification')
                    : const Key('save_transaction'),
                onPressed: _evaluatingJustification
                    ? null
                    : _needsJustification
                    ? _saveJustifiedExpense
                    : _save,
                child: _evaluatingJustification
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _needsJustification
                            ? 'Ask Kolo to evaluate'
                            : _isIncome
                            ? 'Save income'
                            : 'Save expense',
                      ),
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
    final description = _descriptionController.text.trim();
    final date = _parseDateInput(_dateController.text.trim());
    if (amountKobo == null || amountKobo <= 0 || description.isEmpty) {
      setState(() => _error = 'Enter an amount and description.');
      return;
    }
    if (date == null) {
      setState(() => _error = 'Enter a date as YYYY-MM-DD.');
      return;
    }

    if (!_isIncome && _requiresJustification(amountKobo)) {
      setState(() {
        _error = null;
        _needsJustification = true;
        _pendingAmountKobo = amountKobo;
        _pendingDescription = description;
        _pendingDate = date;
        _spendingDecision = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      });
      return;
    }

    await _logTransaction(
      amountKobo: amountKobo,
      description: description,
      date: date,
    );
  }

  Future<void> _saveJustifiedExpense() async {
    final amountKobo = _pendingAmountKobo;
    final description = _pendingDescription;
    final date = _pendingDate;
    final justification = _justificationController.text.trim();

    if (amountKobo == null || description == null || date == null) {
      setState(() => _error = 'Confirm the expense again.');
      return;
    }
    if (justification.isEmpty) {
      setState(() => _error = 'Tell Kolo why this spend still makes sense.');
      return;
    }

    final dashboard = _dashboard();
    if (dashboard == null) {
      setState(() => _error = 'Kolo needs your current money context first.');
      return;
    }

    final transaction = _expenseCandidate(
      amountKobo: amountKobo,
      description: description,
      date: date,
    );
    setState(() {
      _evaluatingJustification = true;
      _error = null;
    });

    try {
      final decision = await widget.ref
          .read(spendingJustificationAdvisorProvider)
          .evaluateSpendingJustification(
            context: dashboard,
            transaction: transaction,
            justification: justification,
            modelName: dashboard.profile.preferredAiModel,
          );
      if (!mounted) return;
      if (decision.approved) {
        await _logTransaction(
          amountKobo: amountKobo,
          description: description,
          date: date,
          decision: decision,
        );
        return;
      }
      setState(() {
        _spendingDecision = decision;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _spendingDecision = SpendingJustificationDecision(
          status: SpendingDecisionStatus.caution,
          message:
              'I could not fully evaluate this right now. If it matters, log it with a note and I will keep it visible.',
          aiNote:
              'Caution - $justification. Kolo could not reach Gemini before logging.',
        );
      });
    } finally {
      if (mounted) setState(() => _evaluatingJustification = false);
    }
  }

  Future<void> _logDecidedExpense({required bool overrideDecision}) async {
    final amountKobo = _pendingAmountKobo;
    final description = _pendingDescription;
    final date = _pendingDate;
    final decision = _spendingDecision;
    if (amountKobo == null ||
        description == null ||
        date == null ||
        decision == null) {
      setState(() => _error = 'Ask Kolo to evaluate the expense first.');
      return;
    }

    final note = overrideDecision && decision.requiresOverride
        ? SpendingJustificationDecision(
            status: decision.status,
            message: decision.message,
            aiNote: '${decision.aiNote} User overrode Kolo advice.',
          )
        : decision;
    await _logTransaction(
      amountKobo: amountKobo,
      description: description,
      date: date,
      decision: note,
    );
  }

  Future<void> _logTransaction({
    required int amountKobo,
    required String description,
    required DateTime date,
    SpendingJustificationDecision? decision,
  }) async {
    final id = 'manual-${DateTime.now().microsecondsSinceEpoch}';
    final aiNote = !_isIncome ? decision?.aiNote : null;
    final transaction = _isIncome
        ? TransactionRecord.income(
            id: id,
            amountKobo: amountKobo,
            category: _category,
            description: description,
            date: date,
            source: TransactionSource.manual,
          )
        : TransactionRecord.expense(
            id: id,
            amountKobo: amountKobo,
            category: _category,
            description: description,
            date: date,
            source: TransactionSource.manual,
            aiApproved: decision?.approved ?? true,
            aiNote: aiNote,
          );

    await widget.ref.read(koloRepositoryProvider).logTransaction(transaction);
    if (mounted) Navigator.of(context).pop();
  }

  bool _requiresJustification(int amountKobo) {
    final dashboard = _dashboard();
    if (dashboard == null) return false;

    final allocatedKobo = _categoryBudgetKobo(dashboard);
    final spendAfter = _categorySpendKobo(dashboard) + amountKobo;
    final overBudget = allocatedKobo > 0 && spendAfter > allocatedKobo;
    final largeAgainstBalance =
        dashboard.balanceKobo > 0 &&
        amountKobo >= (dashboard.balanceKobo * 0.25).round();
    final vaultWarning = _vaultProtectionWarning(amountKobo);
    final billWarning = _billProtectionWarning(amountKobo);

    return overBudget ||
        largeAgainstBalance ||
        vaultWarning.dipsIntoVault ||
        billWarning.risksDueBills;
  }

  String _justificationPromptText() {
    final amountKobo = _pendingAmountKobo;
    final vaultWarning = amountKobo == null
        ? null
        : _vaultProtectionWarning(amountKobo);
    if (vaultWarning != null && vaultWarning.dipsIntoVault) {
      final vaultName = vaultWarning.primaryVaultName ?? 'a vault';
      return 'This spend would touch ${MoneyFormatter.formatKobo(vaultWarning.shortfallKobo)} of protected vault money for $vaultName. What is this for?';
    }
    final billWarning = amountKobo == null
        ? null
        : _billProtectionWarning(amountKobo);
    if (billWarning != null && billWarning.risksDueBills) {
      final billName = billWarning.primaryBillName ?? 'a bill';
      return 'This spend would leave you ${MoneyFormatter.formatKobo(billWarning.shortfallKobo)} short for $billName, a bill due soon. What is this for?';
    }

    return 'This pushes past your $_category budget. What is this for?';
  }

  TransactionRecord _expenseCandidate({
    required int amountKobo,
    required String description,
    required DateTime date,
  }) {
    return TransactionRecord.expense(
      id: 'pending-spend-${DateTime.now().microsecondsSinceEpoch}',
      amountKobo: amountKobo,
      category: _category,
      description: description,
      date: date,
      source: TransactionSource.manual,
    );
  }

  VaultProtectionWarning _vaultProtectionWarning(int amountKobo) {
    final dashboard = _dashboard();
    if (dashboard == null) {
      return const VaultProtectionWarning(
        dipsIntoVault: false,
        protectedKobo: 0,
        shortfallKobo: 0,
      );
    }

    return VaultProtectionAdvisor.check(
      balanceKobo: dashboard.balanceKobo,
      expenseKobo: amountKobo,
      vaults: dashboard.vaults,
    );
  }

  BillProtectionWarning _billProtectionWarning(int amountKobo) {
    final dashboard = _dashboard();
    if (dashboard == null) {
      return const BillProtectionWarning(
        risksDueBills: false,
        reservedKobo: 0,
        shortfallKobo: 0,
      );
    }

    return BillProtectionAdvisor.check(
      balanceKobo: dashboard.balanceKobo,
      expenseKobo: amountKobo,
      bills: dashboard.bills,
    );
  }

  int _categoryBudgetKobo(DashboardState dashboard) {
    for (final category in dashboard.budgetPlan.categories) {
      if (category.name == _category) return category.allocatedKobo;
    }
    return 0;
  }

  int _categorySpendKobo(DashboardState dashboard) {
    return dashboard.transactions
        .where(
          (transaction) =>
              transaction.type == TransactionType.expense &&
              transaction.category == _category,
        )
        .fold<int>(0, (total, transaction) => total + transaction.amountKobo);
  }

  DashboardState? _dashboard() {
    return widget.ref
        .read(dashboardProvider)
        .maybeWhen(data: (state) => state, orElse: () => null);
  }

  DateTime? _parseDateInput(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;

    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  String _dateInput(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _SpendingDecisionCard extends StatelessWidget {
  const _SpendingDecisionCard({
    required this.decision,
    required this.onCancel,
    required this.onLog,
    required this.onOverride,
  });

  final SpendingJustificationDecision decision;
  final VoidCallback onCancel;
  final VoidCallback onLog;
  final VoidCallback onOverride;

  @override
  Widget build(BuildContext context) {
    final color = switch (decision.status) {
      SpendingDecisionStatus.approved => KoloColors.income,
      SpendingDecisionStatus.caution => KoloColors.warning,
      SpendingDecisionStatus.advisedAgainst => KoloColors.expense,
    };
    final title = switch (decision.status) {
      SpendingDecisionStatus.approved => 'Kolo approved this',
      SpendingDecisionStatus.caution => 'Kolo says caution',
      SpendingDecisionStatus.advisedAgainst => 'Kolo advises against this',
    };

    return Container(
      key: const Key('spending_decision_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: KoloColors.primaryPastel,
                child: Icon(Icons.auto_awesome, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: KoloColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      decision.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: KoloColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (decision.approved)
            FilledButton(
              key: const Key('accept_spending_decision'),
              onPressed: onLog,
              child: const Text('Log approved spend'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('cancel_spending_decision'),
                    onPressed: onCancel,
                    child: const Text('Skip it'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('override_spending_decision'),
                    onPressed: onOverride,
                    child: const Text('Do it anyway'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
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
  late final TextEditingController _targetController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _targetController = TextEditingController(
      text: (widget.vault.targetKobo ~/ 100).toString(),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _targetController.dispose();
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
                key: const Key('vault_target_amount'),
                controller: _targetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Target amount',
                  prefixText: '\u20A6 ',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('save_vault_target'),
                onPressed: _saveTarget,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Save target'),
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('delete_vault'),
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete vault'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: KoloColors.expense,
                  side: const BorderSide(color: KoloColors.expense),
                ),
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

  Future<void> _saveTarget() async {
    final targetKobo = MoneyFormatter.parseNairaToKobo(
      _targetController.text.trim(),
    );
    if (targetKobo == null || targetKobo <= 0) {
      setState(() => _error = 'Enter a valid target.');
      return;
    }

    await ref
        .read(koloRepositoryProvider)
        .upsertVault(
          SavingsVault(
            id: widget.vault.id,
            name: widget.vault.name,
            targetKobo: targetKobo,
            currentKobo: widget.vault.currentKobo,
            deadline: widget.vault.deadline,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await ref.read(koloRepositoryProvider).deleteVault(widget.vault.id);
    if (!mounted) return;

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${widget.vault.name} removed from protected funds'),
      ),
    );
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
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  OwingType _filter = OwingType.theyOweMe;
  OwingType _type = OwingType.theyOweMe;
  String? _error;

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _dueDateController.dispose();
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
                SegmentedButton<OwingType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: OwingType.theyOweMe,
                      label: Text(
                        'They owe me',
                        key: Key('owings_filter_they_owe_me'),
                      ),
                    ),
                    ButtonSegment(
                      value: OwingType.iOweThem,
                      label: Text(
                        'I owe them',
                        key: Key('owings_filter_i_owe_them'),
                      ),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (selected) {
                    setState(() => _filter = selected.single);
                  },
                ),
                const SizedBox(height: 14),
                dashboard.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text('Could not load owings: $error'),
                  data: (state) {
                    final visibleOwings = state.owings
                        .where((owing) => owing.type == _filter)
                        .toList(growable: false);
                    if (visibleOwings.isEmpty) {
                      return Container(
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
                          _filter == OwingType.theyOweMe
                              ? 'No one owes you right now.'
                              : 'You do not owe anyone right now.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: KoloColors.textSecondary),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final owing in visibleOwings)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _OwingCard(
                              owing: owing,
                              onTap: () => _openOwingDetail(context, owing),
                            ),
                          ),
                      ],
                    );
                  },
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
                  key: const Key('new_owing_due_date'),
                  controller: _dueDateController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Due date',
                    hintText: 'YYYY-MM-DD (optional)',
                    prefixIcon: Icon(Icons.event_available_outlined),
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
    final dueDate = _parseOwingOptionalDateInput(
      _dueDateController.text.trim(),
    );
    if (person.isEmpty || amountKobo == null || amountKobo <= 0) {
      setState(() => _error = 'Enter a person and amount.');
      return;
    }
    if (_dueDateController.text.trim().isNotEmpty && dueDate == null) {
      setState(() => _error = 'Enter the due date as YYYY-MM-DD.');
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
            dueDate: dueDate,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          ),
        );
    _personController.clear();
    _amountController.clear();
    _dueDateController.clear();
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

DateTime? _parseOwingOptionalDateInput(String value) {
  if (value.isEmpty) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;

  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

class _OwingCard extends StatelessWidget {
  const _OwingCard({required this.owing, required this.onTap});

  final Owing owing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theyOweMe = owing.type == OwingType.theyOweMe;
    final timelineLabel = _owingTimelineLabel(owing.date, DateTime.now());
    final dueLabel = owing.dueDate == null
        ? null
        : 'Due ${_owingDateInput(owing.dueDate!)}';
    final actionLabel = owing.settled
        ? 'Settled'
        : theyOweMe
        ? 'Remind'
        : 'Settle';
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
                    timelineLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: KoloColors.textMuted,
                    ),
                  ),
                  if (dueLabel != null)
                    Text(
                      dueLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: KoloColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  MoneyFormatter.formatKobo(owing.amountKobo),
                  style: TextStyle(
                    color: theyOweMe ? KoloColors.income : KoloColors.expense,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  actionLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: owing.settled
                        ? KoloColors.textMuted
                        : KoloColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _owingTimelineLabel(DateTime date, DateTime now) {
  final opened = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final dayDelta = today.difference(opened).inDays;
  final age = dayDelta == 0
      ? 'today'
      : dayDelta > 0
      ? dayDelta == 1
            ? '1 day ago'
            : '$dayDelta days ago'
      : dayDelta == -1
      ? 'tomorrow'
      : 'in ${dayDelta.abs()} days';

  return '${_owingMonthLabel(date.month)} ${date.day} - $age';
}

String _owingMonthLabel(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (month < 1 || month > months.length) return '';
  return months[month - 1];
}

String _owingDateInput(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class _OwingDetailSheet extends ConsumerStatefulWidget {
  const _OwingDetailSheet({required this.owing});

  final Owing owing;

  @override
  ConsumerState<_OwingDetailSheet> createState() => _OwingDetailSheetState();
}

class _OwingDetailSheetState extends ConsumerState<_OwingDetailSheet> {
  late final TextEditingController _personController;
  late final TextEditingController _amountController;
  late final TextEditingController _dueDateController;
  late final TextEditingController _noteController;
  String? _draft;
  bool _drafting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final owing = widget.owing;
    _personController = TextEditingController(text: owing.person);
    _amountController = TextEditingController(
      text: (owing.amountKobo ~/ 100).toString(),
    );
    _dueDateController = TextEditingController(
      text: owing.dueDate == null ? '' : _owingDateInput(owing.dueDate!),
    );
    _noteController = TextEditingController(text: owing.note ?? '');
  }

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _dueDateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owing = widget.owing;
    final theyOweMe = owing.type == OwingType.theyOweMe;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        key: const Key('owing_detail_sheet'),
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
                Text(
                  owing.person,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _OwingDetailRow(
                  label: theyOweMe ? 'They owe you' : 'You owe them',
                  value: MoneyFormatter.formatKobo(owing.amountKobo),
                  color: theyOweMe ? KoloColors.income : KoloColors.expense,
                ),
                if (owing.note != null)
                  _OwingDetailRow(label: 'Note', value: owing.note!),
                if (owing.dueDate != null)
                  _OwingDetailRow(
                    label: 'Due date',
                    value: _owingDateInput(owing.dueDate!),
                  ),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _draft!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            key: const Key('copy_owing_reminder'),
                            onPressed: _copyDraft,
                            icon: const Icon(Icons.copy_outlined, size: 18),
                            label: const Text('Copy reminder'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                ElevatedButton(
                  key: const Key('settle_owing'),
                  onPressed: owing.settled ? null : _settle,
                  child: const Text('Mark settled'),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    key: const Key('delete_owing'),
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete owing'),
                    style: TextButton.styleFrom(
                      foregroundColor: KoloColors.expense,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Edit owing',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('edit_owing_person'),
                  controller: _personController,
                  decoration: const InputDecoration(labelText: 'Person'),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('edit_owing_amount'),
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\u20A6 ',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('edit_owing_due_date'),
                  controller: _dueDateController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Due date',
                    hintText: 'YYYY-MM-DD (optional)',
                    prefixIcon: Icon(Icons.event_available_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('edit_owing_note'),
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
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('save_owing_edits'),
                  onPressed: _saveEdits,
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('Save owing edits'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _settle() async {
    final owing = widget.owing;
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
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveEdits() async {
    final owing = widget.owing;
    final person = _personController.text.trim();
    final amountKobo = MoneyFormatter.parseNairaToKobo(
      _amountController.text.trim(),
    );
    final dueDateText = _dueDateController.text.trim();
    final dueDate = _parseOwingOptionalDateInput(dueDateText);
    if (person.isEmpty || amountKobo == null || amountKobo <= 0) {
      setState(() => _error = 'Enter a person and amount.');
      return;
    }
    if (dueDateText.isNotEmpty && dueDate == null) {
      setState(() => _error = 'Enter the due date as YYYY-MM-DD.');
      return;
    }

    await ref
        .read(koloRepositoryProvider)
        .upsertOwing(
          Owing(
            id: owing.id,
            type: owing.type,
            person: person,
            amountKobo: amountKobo,
            date: owing.date,
            settled: owing.settled,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            dueDate: dueDate,
          ),
        );
    if (mounted) Navigator.of(context).pop();
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

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await ref.read(koloRepositoryProvider).deleteOwing(widget.owing.id);
    if (!mounted) return;

    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Owing removed')));
  }

  Future<void> _copyDraft() async {
    final draft = _draft;
    if (draft == null) return;

    await Clipboard.setData(ClipboardData(text: draft));
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reminder copied')));
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
