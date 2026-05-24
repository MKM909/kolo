import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/core/widgets/kolo_scaffold.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
      data: (state) => KoloGradientScaffold(
        title: 'Profile',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          children: [
            KoloCard(
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: KoloColors.primaryPastel,
                    child: Icon(Icons.person, color: KoloColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.profile.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(state.profile.email),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ProfileSection(
              title: 'Savings Vaults',
              children: [
                for (final vault in state.vaults)
                  _ProgressRow(
                    label: vault.name,
                    amount:
                        '${MoneyFormatter.formatKobo(vault.currentKobo)} / ${MoneyFormatter.formatKobo(vault.targetKobo)}',
                    progress: vault.progress,
                  ),
              ],
            ),
            _ProfileSection(
              title: 'Owings',
              children: [
                for (final owing in state.owings)
                  _SimpleRow(
                    icon: Icons.handshake_outlined,
                    label: owing.person,
                    value: MoneyFormatter.formatKobo(owing.amountKobo),
                    color: owing.type == OwingType.theyOweMe
                        ? KoloColors.income
                        : KoloColors.expense,
                  ),
              ],
            ),
            _ProfileSection(
              title: 'Gig Tracker',
              action: TextButton(
                key: const Key('open_gig_tracker'),
                onPressed: () => _openGigTrackerSheet(context),
                child: const Text('Add'),
              ),
              children: [
                for (final gig in state.gigs)
                  _SimpleRow(
                    icon: Icons.work_outline,
                    label: gig.client,
                    value: MoneyFormatter.formatKobo(gig.amountKobo),
                    color: KoloColors.income,
                  ),
              ],
            ),
            _ProfileSection(
              title: 'Bill Reminders',
              action: TextButton(
                key: const Key('open_bill_reminders'),
                onPressed: () => _openBillRemindersSheet(context),
                child: const Text('Add'),
              ),
              children: [
                for (final bill in state.bills)
                  _SimpleRow(
                    icon: Icons.receipt_long,
                    label: bill.name,
                    value: MoneyFormatter.formatKobo(bill.amountKobo),
                    color: KoloColors.warning,
                  ),
              ],
            ),
            _ProfileSection(
              title: 'Watched Apps',
              action: TextButton(
                key: const Key('open_watched_apps'),
                onPressed: () => _openWatchedAppsSheet(context),
                child: const Text('Manage'),
              ),
              children: [
                for (final app in state.watchedApps)
                  _SimpleRow(
                    icon: Icons.visibility_outlined,
                    label: app.displayName,
                    value: app.enabled ? 'On' : 'Off',
                    color: app.enabled
                        ? KoloColors.primary
                        : KoloColors.textMuted,
                  ),
              ],
            ),
            _ProfileSection(
              title: 'Partner Sharing',
              action: TextButton(
                key: const Key('open_partner_sharing'),
                onPressed: () => _openPartnerSharingSheet(context),
                child: const Text('Manage'),
              ),
              children: [
                for (final share in state.partnerShares)
                  _SimpleRow(
                    icon: Icons.verified_user_outlined,
                    label: share.partnerEmail,
                    value: share.status.name,
                    color: KoloColors.primary,
                  ),
              ],
            ),
            _ProfileSection(
              title: 'Permissions',
              children: [
                for (final entry in state.permissions.entries)
                  _PermissionRow(
                    permission: entry.key,
                    state: entry.value,
                    onGrant: () => ref
                        .read(koloRepositoryProvider)
                        .updatePermission(
                          entry.key,
                          PermissionGrantState.granted,
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGigTrackerSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _GigTrackerSheet(),
    );
  }

  Future<void> _openBillRemindersSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _BillRemindersSheet(),
    );
  }

  Future<void> _openPartnerSharingSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PartnerSharingSheet(),
    );
  }

  Future<void> _openWatchedAppsSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _WatchedAppsSheet(),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.permission,
    required this.state,
    required this.onGrant,
  });

  final KoloPermission permission;
  final PermissionGrantState state;
  final Future<void> Function() onGrant;

  @override
  Widget build(BuildContext context) {
    final granted = state == PermissionGrantState.granted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            granted ? Icons.lock_open_outlined : Icons.lock_outline,
            color: granted ? KoloColors.income : KoloColors.warning,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(permission.name)),
          if (granted)
            const Text(
              'granted',
              style: TextStyle(
                color: KoloColors.income,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            TextButton(
              key: Key('grant_${permission.name}'),
              onPressed: onGrant,
              child: const Text('Enable'),
            ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.children,
    this.action,
  });

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: KoloCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _GigTrackerSheet extends ConsumerStatefulWidget {
  const _GigTrackerSheet();

  @override
  ConsumerState<_GigTrackerSheet> createState() => _GigTrackerSheetState();
}

class _GigTrackerSheetState extends ConsumerState<_GigTrackerSheet> {
  final TextEditingController _clientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _projectTypeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _clientController.dispose();
    _amountController.dispose();
    _projectTypeController.dispose();
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
        key: const Key('gig_tracker_sheet'),
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
                  'Gig Tracker',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                dashboard.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text('Could not load gigs: $error'),
                  data: (state) => Column(
                    children: [
                      for (final gig in state.gigs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _GigCard(gig: gig),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text('New gig', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('new_gig_client'),
                  controller: _clientController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Client'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('new_gig_amount'),
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\u20A6 ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('new_gig_project_type'),
                  controller: _projectTypeController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Project type'),
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
                  key: const Key('save_new_gig'),
                  onPressed: _save,
                  child: const Text('Save gig'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final client = _clientController.text.trim();
    final amountKobo = MoneyFormatter.parseNairaToKobo(
      _amountController.text.trim(),
    );
    final projectType = _projectTypeController.text.trim();

    if (client.isEmpty || amountKobo == null || amountKobo <= 0) {
      setState(() => _error = 'Enter a client and amount.');
      return;
    }

    final now = DateTime.now();
    await ref
        .read(koloRepositoryProvider)
        .upsertGig(
          GigRecord(
            id: 'gig-${now.microsecondsSinceEpoch}',
            client: client,
            amountKobo: amountKobo,
            date: now,
            projectType: projectType.isEmpty ? 'Gig' : projectType,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          ),
        );
    _clientController.clear();
    _amountController.clear();
    _projectTypeController.clear();
    _noteController.clear();
    if (mounted) setState(() => _error = null);
  }
}

class _GigCard extends StatelessWidget {
  const _GigCard({required this.gig});

  final GigRecord gig;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: KoloColors.primaryPastel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.work_outline, color: KoloColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gig.client,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  gig.projectType,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          Text(
            MoneyFormatter.formatKobo(gig.amountKobo),
            style: const TextStyle(
              color: KoloColors.income,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillRemindersSheet extends ConsumerStatefulWidget {
  const _BillRemindersSheet();

  @override
  ConsumerState<_BillRemindersSheet> createState() =>
      _BillRemindersSheetState();
}

class _BillRemindersSheetState extends ConsumerState<_BillRemindersSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController(
    text: 'Monthly',
  );
  late final TextEditingController _nextDueController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nextDueController = TextEditingController(
      text: _dateInput(DateTime.now().add(const Duration(days: 7))),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _frequencyController.dispose();
    _nextDueController.dispose();
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
        key: const Key('bill_reminders_sheet'),
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
                  'Bill Reminders',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                dashboard.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text('Could not load bills: $error'),
                  data: (state) => Column(
                    children: [
                      for (final bill in state.bills)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _BillCard(
                            bill: bill,
                            onTap: () => _openBillDetail(context, bill),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'New bill',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('new_bill_name'),
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('new_bill_amount'),
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\u20A6 ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('new_bill_frequency'),
                  controller: _frequencyController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('new_bill_next_due'),
                  controller: _nextDueController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(labelText: 'Next due date'),
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
                  key: const Key('save_new_bill'),
                  onPressed: _save,
                  child: const Text('Save bill'),
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
    final amountKobo = MoneyFormatter.parseNairaToKobo(
      _amountController.text.trim(),
    );
    final frequency = _frequencyController.text.trim();
    final nextDue = DateTime.tryParse(_nextDueController.text.trim());

    if (name.isEmpty ||
        amountKobo == null ||
        amountKobo <= 0 ||
        frequency.isEmpty ||
        nextDue == null) {
      setState(() => _error = 'Enter bill details and a due date.');
      return;
    }

    final now = DateTime.now();
    await ref
        .read(koloRepositoryProvider)
        .upsertBill(
          BillReminder(
            id: 'bill-${now.microsecondsSinceEpoch}',
            name: name,
            amountKobo: amountKobo,
            frequency: frequency,
            nextDue: nextDue,
          ),
        );
    _nameController.clear();
    _amountController.clear();
    if (mounted) setState(() => _error = null);
  }

  Future<void> _openBillDetail(BuildContext context, BillReminder bill) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BillDetailSheet(bill: bill),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, required this.onTap});

  final BillReminder bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = bill.active ? KoloColors.warning : KoloColors.textMuted;
    return InkWell(
      key: Key('bill_card_${bill.id}'),
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
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
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: KoloColors.primaryPastel,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.receipt_long, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${bill.frequency} - ${_dateInput(bill.nextDue)}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  if (!bill.active) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Paused',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: KoloColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              MoneyFormatter.formatKobo(bill.amountKobo),
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillDetailSheet extends ConsumerWidget {
  const _BillDetailSheet({required this.bill});

  final BillReminder bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: const Key('bill_detail_sheet'),
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
            Text(bill.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _ProfileMetricRow(
              label: 'Amount',
              value: MoneyFormatter.formatKobo(bill.amountKobo),
            ),
            _ProfileMetricRow(label: 'Frequency', value: bill.frequency),
            _ProfileMetricRow(
              label: 'Next due',
              value: _dateInput(bill.nextDue),
            ),
            _ProfileMetricRow(
              label: 'Status',
              value: bill.active ? 'Active' : 'Paused',
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              key: Key('mark_bill_paid_${bill.id}'),
              onPressed: () => _markPaid(context, ref),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Mark paid'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: Key('pause_bill_${bill.id}'),
              onPressed: bill.active
                  ? () async {
                      await ref
                          .read(koloRepositoryProvider)
                          .upsertBill(
                            BillReminder(
                              id: bill.id,
                              name: bill.name,
                              amountKobo: bill.amountKobo,
                              frequency: bill.frequency,
                              nextDue: bill.nextDue,
                              active: false,
                            ),
                          );
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  : null,
              icon: const Icon(Icons.pause_circle_outline),
              label: const Text('Pause reminder'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markPaid(BuildContext context, WidgetRef ref) async {
    final dashboard = ref
        .read(dashboardProvider)
        .maybeWhen(data: (state) => state, orElse: () => null);
    final nextDue = _nextBillDue(bill.nextDue, bill.frequency);
    final now = DateTime.now();
    final repository = ref.read(koloRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await repository.logTransaction(
      TransactionRecord.expense(
        id: 'bill-paid-${bill.id}-${now.microsecondsSinceEpoch}',
        amountKobo: bill.amountKobo,
        category: 'Utilities & Bills',
        description: '${bill.name} paid',
        date: now,
        source: TransactionSource.manual,
        merchantName: bill.name,
        aiApproved: true,
        aiNote: 'Bill marked paid from reminders.',
      ),
    );
    await repository.upsertBill(
      BillReminder(
        id: bill.id,
        name: bill.name,
        amountKobo: bill.amountKobo,
        frequency: bill.frequency,
        nextDue: nextDue,
        active: bill.active,
      ),
    );

    final balanceAfter = (dashboard?.balanceKobo ?? 0) - bill.amountKobo;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${bill.name} paid. Balance is now ${MoneyFormatter.formatKobo(balanceAfter)}.',
        ),
      ),
    );
  }
}

class _ProfileMetricRow extends StatelessWidget {
  const _ProfileMetricRow({required this.label, required this.value});

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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

String _dateInput(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime _nextBillDue(DateTime currentDue, String frequency) {
  final normalized = frequency.toLowerCase();
  if (normalized.contains('week')) {
    return currentDue.add(const Duration(days: 7));
  }
  if (normalized.contains('year') || normalized.contains('annual')) {
    return DateTime(currentDue.year + 1, currentDue.month, currentDue.day);
  }
  if (normalized.contains('day')) {
    return currentDue.add(const Duration(days: 1));
  }
  return DateTime(currentDue.year, currentDue.month + 1, currentDue.day);
}

class _PartnerSharingSheet extends ConsumerStatefulWidget {
  const _PartnerSharingSheet();

  @override
  ConsumerState<_PartnerSharingSheet> createState() =>
      _PartnerSharingSheetState();
}

class _PartnerSharingSheetState extends ConsumerState<_PartnerSharingSheet> {
  static const _permissionOptions = {
    'balance_summary': 'Balance summary',
    'budget_summary': 'Budget summary',
    'vault_goals': 'Vault goals',
    'owings': 'Owings',
    'bills': 'Bills',
    'weekly_insights': 'Weekly insights',
  };

  final TextEditingController _emailController = TextEditingController();
  final Set<String> _selectedPermissions = {
    'balance_summary',
    'budget_summary',
    'weekly_insights',
  };
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
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
        key: const Key('partner_sharing_sheet'),
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
                  'Partner Sharing',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                dashboard.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text('Could not load shares: $error'),
                  data: (state) => Column(
                    children: [
                      for (final share in state.partnerShares)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PartnerShareCard(
                            share: share,
                            onRevoke: () => _revoke(share),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Invite partner',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('new_partner_email'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                for (final option in _permissionOptions.entries)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: KoloColors.primary,
                    title: Text(option.value),
                    value: _selectedPermissions.contains(option.key),
                    onChanged: (selected) {
                      setState(() {
                        if (selected ?? false) {
                          _selectedPermissions.add(option.key);
                        } else {
                          _selectedPermissions.remove(option.key);
                        }
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
                const SizedBox(height: 18),
                ElevatedButton(
                  key: const Key('save_new_partner'),
                  onPressed: _save,
                  child: const Text('Invite partner'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || _selectedPermissions.isEmpty) {
      setState(() => _error = 'Enter an email and choose at least one area.');
      return;
    }

    final now = DateTime.now();
    await ref
        .read(koloRepositoryProvider)
        .upsertPartnerShare(
          PartnerShare(
            id: 'share-${now.microsecondsSinceEpoch}',
            partnerEmail: email,
            status: ShareStatus.pending,
            permissions: Set.unmodifiable(_selectedPermissions),
            createdAt: now,
          ),
        );
    _emailController.clear();
    if (mounted) setState(() => _error = null);
  }

  Future<void> _revoke(PartnerShare share) async {
    await ref
        .read(koloRepositoryProvider)
        .upsertPartnerShare(
          PartnerShare(
            id: share.id,
            partnerEmail: share.partnerEmail,
            status: ShareStatus.revoked,
            permissions: share.permissions,
            createdAt: share.createdAt,
            revokedAt: DateTime.now(),
          ),
        );
  }
}

class _PartnerShareCard extends StatelessWidget {
  const _PartnerShareCard({required this.share, required this.onRevoke});

  final PartnerShare share;
  final Future<void> Function() onRevoke;

  @override
  Widget build(BuildContext context) {
    final revoked = share.status == ShareStatus.revoked;
    final color = revoked ? KoloColors.textMuted : KoloColors.primary;
    return Container(
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
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: KoloColors.primaryPastel,
            child: Icon(Icons.verified_user_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  share.partnerEmail,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  share.status.name,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: color),
                ),
              ],
            ),
          ),
          TextButton(
            key: Key('revoke_partner_${share.id}'),
            onPressed: revoked ? null : onRevoke,
            child: Text(revoked ? 'Revoked' : 'Revoke'),
          ),
        ],
      ),
    );
  }
}

class _WatchedAppsSheet extends ConsumerStatefulWidget {
  const _WatchedAppsSheet();

  @override
  ConsumerState<_WatchedAppsSheet> createState() => _WatchedAppsSheetState();
}

class _WatchedAppsSheetState extends ConsumerState<_WatchedAppsSheet> {
  bool _refreshing = false;
  String? _refreshError;

  Future<void> _refreshSuggestedApps() async {
    setState(() {
      _refreshing = true;
      _refreshError = null;
    });

    try {
      final suggestions = await ref
          .read(androidCapabilityServiceProvider)
          .getSuggestedBankingApps();
      final currentState = ref
          .read(dashboardProvider)
          .maybeWhen(data: (state) => state, orElse: () => null);
      final existingApps = {
        for (final app in currentState?.watchedApps ?? const <WatchedApp>[])
          app.packageName: app,
      };

      for (final suggestion in suggestions) {
        final existing = existingApps[suggestion.packageName];
        await ref
            .read(koloRepositoryProvider)
            .upsertWatchedApp(
              WatchedApp(
                packageName: suggestion.packageName,
                displayName: suggestion.displayName,
                enabled: existing?.enabled ?? false,
              ),
            );
      }

      if (mounted && suggestions.isEmpty) {
        setState(() => _refreshError = 'No banking apps found yet.');
      }
    } catch (error) {
      if (mounted) setState(() => _refreshError = 'Could not refresh apps.');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);
    return Container(
      key: const Key('watched_apps_sheet'),
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
                'Watched Apps',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('refresh_watched_apps'),
                onPressed: _refreshing ? null : _refreshSuggestedApps,
                icon: _refreshing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Refresh apps'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: KoloColors.primary,
                  side: const BorderSide(color: KoloColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
              if (_refreshError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _refreshError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KoloColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              dashboard.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Could not load apps: $error'),
                data: (state) => Column(
                  children: [
                    for (final app in state.watchedApps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _WatchedAppToggle(app: app),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchedAppToggle extends ConsumerWidget {
  const _WatchedAppToggle({required this.app});

  final WatchedApp app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
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
      child: SwitchListTile(
        key: Key('toggle_watched_app_${app.packageName}'),
        value: app.enabled,
        activeThumbColor: KoloColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: CircleAvatar(
          backgroundColor: KoloColors.primaryPastel,
          child: Icon(
            Icons.visibility_outlined,
            color: app.enabled ? KoloColors.primary : KoloColors.textMuted,
          ),
        ),
        title: Text(
          app.displayName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(app.enabled ? 'On' : 'Off'),
        onChanged: (enabled) async {
          await ref
              .read(koloRepositoryProvider)
              .upsertWatchedApp(
                WatchedApp(
                  packageName: app.packageName,
                  displayName: app.displayName,
                  enabled: enabled,
                ),
              );
        },
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.amount,
    required this.progress,
  });

  final String label;
  final String amount;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(amount),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            color: KoloColors.primary,
            backgroundColor: KoloColors.primaryPastel,
          ),
        ],
      ),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
