import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/data/services/offline_sync_queue.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/ai_model_config.dart';
import 'package:kolo/domain/services/bill_reminder_schedule.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/core/widgets/balance_adjustment_sheet.dart';
import 'package:kolo/ui/core/widgets/kolo_scaffold.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final pendingSync = ref.watch(pendingSyncOperationsProvider);
    ref.watch(permissionStatusRefreshProvider);

    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
      data: (state) => KoloGradientScaffold(
        title: 'Profile',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 160),
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
                  const SizedBox(width: 12),
                  _SyncStatusPill(syncState: pendingSync),
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
              title: 'AI Chat History',
              action: TextButton(
                key: const Key('open_ai_history'),
                onPressed: () => _openAiHistorySheet(context),
                child: const Text('Manage'),
              ),
              children: [
                _SimpleRow(
                  icon: Icons.auto_awesome,
                  label: 'Saved messages',
                  value: '${state.aiMessages.length}',
                  color: KoloColors.primary,
                ),
              ],
            ),
            _ProfileSection(
              title: 'Notification Preferences',
              action: TextButton(
                onPressed: () => _openNotificationPreferencesSheet(context),
                child: const Text('Manage'),
              ),
              children: [
                InkWell(
                  key: const Key('open_notification_preferences'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openNotificationPreferencesSheet(context),
                  child: _SimpleRow(
                    icon: Icons.notifications_none,
                    label: 'Active nudges',
                    value:
                        '${_enabledNotificationPreferenceCount(state.profile.notificationPreferences)} / 5',
                    color: KoloColors.primary,
                  ),
                ),
              ],
            ),
            _ProfileSection(
              title: 'Kolo AI Model',
              action: TextButton(
                onPressed: () => _openAiModelSettingsSheet(context),
                child: const Text('Change'),
              ),
              children: [
                InkWell(
                  key: const Key('open_ai_model_settings'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openAiModelSettingsSheet(context),
                  child: _SimpleRow(
                    icon: Icons.auto_awesome,
                    label: 'Default for Gemini calls',
                    value: koloAiModelLabel(state.profile.preferredAiModel),
                    color: KoloColors.primary,
                  ),
                ),
              ],
            ),
            _ProfileSection(
              title: 'Budget Settings',
              children: [
                InkWell(
                  key: const Key('open_budget_settings'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.go('/budget'),
                  child: const _SimpleRow(
                    icon: Icons.pie_chart_outline,
                    label: 'Budget screen',
                    value: 'Open',
                    color: KoloColors.primary,
                  ),
                ),
              ],
            ),
            _ProfileSection(
              title: 'Balance Adjustment',
              children: [
                InkWell(
                  key: const Key('open_profile_balance_adjustment'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openBalanceAdjustmentSheet(
                    context,
                    currentBalanceKobo: state.balanceKobo,
                  ),
                  child: _SimpleRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Current balance',
                    value: MoneyFormatter.formatKobo(state.balanceKobo),
                    color: KoloColors.primary,
                  ),
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
            _ProfileSection(
              title: 'About Kolo',
              children: const [
                _SimpleRow(
                  icon: Icons.info_outline,
                  label: 'Kolo v1',
                  value: 'Android-first',
                  color: KoloColors.primary,
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('profile_sign_out'),
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Signed out of Kolo.')),
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: KoloColors.expense,
                  side: const BorderSide(color: KoloColors.expense),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
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

  Future<void> _openAiHistorySheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AiHistorySheet(),
    );
  }

  Future<void> _openNotificationPreferencesSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _NotificationPreferencesSheet(),
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

  Future<void> _openAiModelSettingsSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AiModelSettingsSheet(),
    );
  }
}

class _NotificationPreferencesSheet extends ConsumerWidget {
  const _NotificationPreferencesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return Container(
      key: const Key('notification_preferences_sheet'),
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
      child: SafeArea(
        top: false,
        child: dashboard.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Could not load preferences: $error'),
          data: (state) {
            final preferences = state.profile.notificationPreferences;
            return SingleChildScrollView(
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
                    'Notification Preferences',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 18),
                  _NotificationPreferenceTile(
                    id: 'transactionAlerts',
                    icon: Icons.receipt_long,
                    label: 'Transaction alerts',
                    value: preferences.transactionAlerts,
                    onChanged: (value) => ref
                        .read(koloRepositoryProvider)
                        .updateNotificationPreferences(
                          preferences.copyWith(transactionAlerts: value),
                        ),
                  ),
                  _NotificationPreferenceTile(
                    id: 'budgetWarnings',
                    icon: Icons.warning_amber_outlined,
                    label: 'Budget warnings',
                    value: preferences.budgetWarnings,
                    onChanged: (value) => ref
                        .read(koloRepositoryProvider)
                        .updateNotificationPreferences(
                          preferences.copyWith(budgetWarnings: value),
                        ),
                  ),
                  _NotificationPreferenceTile(
                    id: 'billReminders',
                    icon: Icons.event_note_outlined,
                    label: 'Bill reminders',
                    value: preferences.billReminders,
                    onChanged: (value) => ref
                        .read(koloRepositoryProvider)
                        .updateNotificationPreferences(
                          preferences.copyWith(billReminders: value),
                        ),
                  ),
                  _NotificationPreferenceTile(
                    id: 'weeklyInsights',
                    icon: Icons.insights_outlined,
                    label: 'Weekly insights',
                    value: preferences.weeklyInsights,
                    onChanged: (value) => ref
                        .read(koloRepositoryProvider)
                        .updateNotificationPreferences(
                          preferences.copyWith(weeklyInsights: value),
                        ),
                  ),
                  _NotificationPreferenceTile(
                    id: 'bubbleInterventions',
                    icon: Icons.auto_awesome,
                    label: 'Bubble interventions',
                    value: preferences.bubbleInterventions,
                    onChanged: (value) => ref
                        .read(koloRepositoryProvider)
                        .updateNotificationPreferences(
                          preferences.copyWith(bubbleInterventions: value),
                        ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationPreferenceTile extends StatelessWidget {
  const _NotificationPreferenceTile({
    required this.id,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String id;
  final IconData icon;
  final String label;
  final bool value;
  final Future<void> Function(bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
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
          key: Key('toggle_preference_$id'),
          value: value,
          activeThumbColor: KoloColors.primary,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          secondary: CircleAvatar(
            backgroundColor: KoloColors.primaryPastel,
            child: Icon(
              icon,
              color: value ? KoloColors.primary : KoloColors.textMuted,
            ),
          ),
          title: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(value ? 'On' : 'Off'),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _AiModelSettingsSheet extends ConsumerWidget {
  const _AiModelSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return Container(
      key: const Key('ai_model_settings_sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
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
        child: dashboard.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Could not load AI settings: $error'),
          data: (state) {
            final selected = state.profile.preferredAiModel;
            return SingleChildScrollView(
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
                    'Kolo AI Model',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose the Gemini model Kolo uses for chat, budgets, reminders, and insights.',
                    style: TextStyle(color: KoloColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  for (final option in koloAiModelOptions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AiModelOptionTile(
                        option: option,
                        selected: option.modelName == selected,
                        onTap: () => ref
                            .read(koloRepositoryProvider)
                            .updatePreferredAiModel(option.modelName),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AiModelOptionTile extends StatelessWidget {
  const _AiModelOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AiModelOption option;
  final bool selected;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('ai_model_option_${koloAiModelKeySlug(option.modelName)}'),
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? KoloColors.primaryPastel : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? KoloColors.primary : const Color(0xFFEDE9FE),
            width: selected ? 1.5 : 1,
          ),
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
              backgroundColor: selected
                  ? KoloColors.primary
                  : KoloColors.primaryPastel,
              child: Icon(
                Icons.auto_awesome,
                color: selected ? Colors.white : KoloColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.description,
                    style: const TextStyle(
                      color: KoloColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? KoloColors.primary : KoloColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _AiHistorySheet extends ConsumerWidget {
  const _AiHistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return Container(
      key: const Key('ai_history_sheet'),
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
        child: dashboard.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Could not load chat history: $error'),
          data: (state) => SingleChildScrollView(
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
                  'AI Chat History',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (state.aiMessages.isEmpty)
                  const Text(
                    'No messages yet.',
                    style: TextStyle(color: KoloColors.textSecondary),
                  )
                else
                  for (final message in state.aiMessages.take(8))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AiHistoryMessage(message: message),
                    ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('clear_ai_history'),
                    onPressed: state.aiMessages.isEmpty
                        ? null
                        : () async {
                            await ref
                                .read(koloRepositoryProvider)
                                .clearAiMessages();
                            if (context.mounted) Navigator.of(context).pop();
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear history'),
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

class _AiHistoryMessage extends StatelessWidget {
  const _AiHistoryMessage({required this.message});

  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AiRole.user;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUser ? KoloColors.primaryPastel : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUser ? 'You' : 'Kolo',
            style: TextStyle(
              color: isUser ? KoloColors.primary : KoloColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(message.content),
        ],
      ),
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

class _SyncStatusPill extends StatelessWidget {
  const _SyncStatusPill({required this.syncState});

  final AsyncValue<List<PendingSyncOperation>> syncState;

  @override
  Widget build(BuildContext context) {
    final operations = syncState.value ?? const <PendingSyncOperation>[];
    final hasPending = operations.isNotEmpty;
    final hasError = syncState.hasError && !syncState.hasValue;
    final color = hasError
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
      key: const Key('profile_sync_status'),
      constraints: const BoxConstraints(maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: KoloColors.primaryPastel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: KoloColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(countLabel, style: TextStyle(color: color)),
              ],
            ),
          ),
        ],
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
                  data: (state) {
                    final now = DateTime.now();
                    final thisMonthKobo = _gigTotalForPeriod(
                      state.gigs,
                      now,
                      matchMonth: true,
                    );
                    final thisYearKobo = _gigTotalForPeriod(state.gigs, now);
                    final latestGig = _latestGig(state.gigs);
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _GigSummaryTile(
                                key: const Key('gig_summary_this_month'),
                                label: 'This month',
                                amountKobo: thisMonthKobo,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _GigSummaryTile(
                                key: const Key('gig_summary_this_year'),
                                label: 'This year',
                                amountKobo: thisYearKobo,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _GigCadenceCard(latestGig: latestGig, now: now),
                        const SizedBox(height: 12),
                        for (final gig in state.gigs)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _GigCard(gig: gig),
                          ),
                      ],
                    );
                  },
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

class _GigSummaryTile extends StatelessWidget {
  const _GigSummaryTile({
    super.key,
    required this.label,
    required this.amountKobo,
  });

  final String label;
  final int amountKobo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: KoloColors.textSecondary),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              MoneyFormatter.formatKobo(amountKobo),
              maxLines: 1,
              style: const TextStyle(
                color: KoloColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GigCadenceCard extends StatelessWidget {
  const _GigCadenceCard({required this.latestGig, required this.now});

  final GigRecord? latestGig;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = latestGig == null
        ? 'No gigs logged yet. Kolo will track your first one here.'
        : '${_daysSinceGigLabel(latestGig!.date, now)} since your last gig income.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KoloColors.primaryPastel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: KoloColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: KoloColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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

int _gigTotalForPeriod(
  List<GigRecord> gigs,
  DateTime now, {
  bool matchMonth = false,
}) {
  return gigs
      .where(
        (gig) =>
            gig.date.year == now.year &&
            (!matchMonth || gig.date.month == now.month),
      )
      .fold<int>(0, (total, gig) => total + gig.amountKobo);
}

GigRecord? _latestGig(List<GigRecord> gigs) {
  if (gigs.isEmpty) return null;
  return gigs.reduce((latest, gig) {
    return gig.date.isAfter(latest.date) ? gig : latest;
  });
}

String _daysSinceGigLabel(DateTime date, DateTime now) {
  final gigDay = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(gigDay).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return '1 day';
  return '$days days';
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
                  data: (state) {
                    final dueSoon = _billsWithUrgency(state.bills, {
                      BillReminderUrgency.overdue,
                      BillReminderUrgency.dueToday,
                      BillReminderUrgency.dueSoon,
                    });
                    final upcoming = _billsWithUrgency(state.bills, {
                      BillReminderUrgency.upcoming,
                    });
                    final paused = _billsWithUrgency(state.bills, {
                      BillReminderUrgency.paused,
                    });
                    return Column(
                      children: [
                        if (dueSoon.isNotEmpty)
                          _BillSection(
                            key: const Key('bill_section_due_soon'),
                            title: 'Due soon',
                            bills: dueSoon,
                            onOpen: (bill) => _openBillDetail(context, bill),
                          ),
                        if (upcoming.isNotEmpty)
                          _BillSection(
                            key: const Key('bill_section_upcoming'),
                            title: 'Upcoming',
                            bills: upcoming,
                            onOpen: (bill) => _openBillDetail(context, bill),
                          ),
                        if (paused.isNotEmpty)
                          _BillSection(
                            key: const Key('bill_section_paused'),
                            title: 'Paused',
                            bills: paused,
                            onOpen: (bill) => _openBillDetail(context, bill),
                          ),
                        if (state.bills.isEmpty)
                          const Text(
                            'No bill reminders yet.',
                            style: TextStyle(color: KoloColors.textSecondary),
                          ),
                      ],
                    );
                  },
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

class _BillSection extends StatelessWidget {
  const _BillSection({
    super.key,
    required this.title,
    required this.bills,
    required this.onOpen,
  });

  final String title;
  final List<BillReminder> bills;
  final void Function(BillReminder bill) onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: KoloColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final bill in bills)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BillCard(bill: bill, onTap: () => onOpen(bill)),
            ),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, required this.onTap});

  final BillReminder bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = BillReminderSchedule.statusFor(bill);
    final statusColor = switch (status.urgency) {
      BillReminderUrgency.overdue => KoloColors.expense,
      BillReminderUrgency.dueToday ||
      BillReminderUrgency.dueSoon => KoloColors.warning,
      BillReminderUrgency.paused => KoloColors.textMuted,
      BillReminderUrgency.upcoming => KoloColors.primary,
    };
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
                  const SizedBox(height: 4),
                  Text(
                    status.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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

List<BillReminder> _billsWithUrgency(
  List<BillReminder> bills,
  Set<BillReminderUrgency> urgencies,
) {
  return bills
      .where(
        (bill) =>
            urgencies.contains(BillReminderSchedule.statusFor(bill).urgency),
      )
      .toList(growable: false);
}

class _BillDetailSheet extends ConsumerStatefulWidget {
  const _BillDetailSheet({required this.bill});

  final BillReminder bill;

  @override
  ConsumerState<_BillDetailSheet> createState() => _BillDetailSheetState();
}

class _BillDetailSheetState extends ConsumerState<_BillDetailSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _frequencyController;
  late final TextEditingController _nextDueController;
  String? _error;

  BillReminder get bill => widget.bill;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: (bill.amountKobo ~/ 100).toString(),
    );
    _frequencyController = TextEditingController(text: bill.frequency);
    _nextDueController = TextEditingController(text: _dateInput(bill.nextDue));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _frequencyController.dispose();
    _nextDueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        key: const Key('bill_detail_sheet'),
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
                  value: BillReminderSchedule.statusFor(bill).label,
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
                  onPressed: bill.active ? _pause : null,
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('Pause reminder'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: Key('delete_bill_${bill.id}'),
                  onPressed: () => _delete(context, ref),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete reminder'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KoloColors.expense,
                    side: const BorderSide(color: KoloColors.expense),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Edit reminder',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: Key('edit_bill_amount_${bill.id}'),
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\u20A6 ',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: Key('edit_bill_frequency_${bill.id}'),
                  controller: _frequencyController,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: Key('edit_bill_next_due_${bill.id}'),
                  controller: _nextDueController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Next due date',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: Icon(Icons.event_available_outlined),
                  ),
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
                  key: Key('save_bill_edits_${bill.id}'),
                  onPressed: _saveEdits,
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Save bill edits'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markPaid(BuildContext context, WidgetRef ref) async {
    final dashboard = ref
        .read(dashboardProvider)
        .maybeWhen(data: (state) => state, orElse: () => null);
    final nextDue = BillReminderSchedule.nextDueAfter(
      bill.nextDue,
      bill.frequency,
    );
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

  Future<void> _saveEdits() async {
    final amountKobo = MoneyFormatter.parseNairaToKobo(
      _amountController.text.trim(),
    );
    final frequency = _frequencyController.text.trim();
    final nextDue = DateTime.tryParse(_nextDueController.text.trim());
    if (amountKobo == null ||
        amountKobo <= 0 ||
        frequency.isEmpty ||
        nextDue == null) {
      setState(() => _error = 'Enter bill amount, frequency, and due date.');
      return;
    }

    await ref
        .read(koloRepositoryProvider)
        .upsertBill(
          BillReminder(
            id: bill.id,
            name: bill.name,
            amountKobo: amountKobo,
            frequency: frequency,
            nextDue: nextDue,
            active: bill.active,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pause() async {
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
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await ref.read(koloRepositoryProvider).deleteBill(bill.id);
    if (!context.mounted) return;

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('${bill.name} reminder removed')),
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

int _enabledNotificationPreferenceCount(NotificationPreferences preferences) {
  return [
    preferences.transactionAlerts,
    preferences.budgetWarnings,
    preferences.billReminders,
    preferences.weeklyInsights,
    preferences.bubbleInterventions,
  ].where((enabled) => enabled).length;
}

const _partnerPermissionLabels = {
  'balance_summary': 'Balance summary',
  'budget_summary': 'Budget summary',
  'vault_goals': 'Vault goals',
  'owings': 'Owings',
  'bills': 'Bills',
  'weekly_insights': 'Weekly insights',
};

class _PartnerSharingSheet extends ConsumerStatefulWidget {
  const _PartnerSharingSheet();

  @override
  ConsumerState<_PartnerSharingSheet> createState() =>
      _PartnerSharingSheetState();
}

class _PartnerSharingSheetState extends ConsumerState<_PartnerSharingSheet> {
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
                            ownerUid: state.profile.uid,
                            onRevoke: () => _revoke(share),
                            onPublish: () => _publish(share),
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
                for (final option in _partnerPermissionLabels.entries)
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

  Future<void> _publish(PartnerShare share) async {
    final summary = await ref
        .read(koloRepositoryProvider)
        .publishPartnerSummary(share);
    if (!mounted) return;

    final message = summary == null
        ? 'Partner share is not active'
        : 'Partner-safe summary published for ${share.partnerEmail}';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PartnerShareCard extends StatelessWidget {
  const _PartnerShareCard({
    required this.share,
    required this.ownerUid,
    required this.onRevoke,
    required this.onPublish,
  });

  final PartnerShare share;
  final String ownerUid;
  final Future<void> Function() onRevoke;
  final Future<void> Function() onPublish;

  @override
  Widget build(BuildContext context) {
    final revoked = share.status == ShareStatus.revoked;
    final color = revoked ? KoloColors.textMuted : KoloColors.primary;
    final inviteLink = PartnerInviteRef(
      ownerUid: ownerUid,
      shareId: share.id,
    ).deepLink.toString();
    return Container(
      key: Key('partner_share_card_${share.id}'),
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
                    const SizedBox(height: 4),
                    Text(
                      _partnerPermissionSummary(share.permissions),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: KoloColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!revoked) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: KoloColors.primaryPastel,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      inviteLink,
                      key: Key('partner_invite_link_${share.id}'),
                      style: const TextStyle(
                        color: KoloColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('copy_partner_invite_${share.id}'),
                    tooltip: 'Copy invite link',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: inviteLink));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite link copied')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                key: Key('publish_partner_${share.id}'),
                onPressed: revoked ? null : onPublish,
                icon: const Icon(Icons.ios_share_outlined, size: 18),
                label: const Text('Publish summary'),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: Key('revoke_partner_${share.id}'),
                onPressed: revoked ? null : onRevoke,
                child: Text(revoked ? 'Revoked' : 'Revoke'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _partnerPermissionSummary(Set<String> permissions) {
  final labels = [
    for (final entry in _partnerPermissionLabels.entries)
      if (permissions.contains(entry.key)) entry.value,
  ];
  if (labels.isEmpty) return 'No shared areas';
  return labels.join(', ');
}

class _WatchedAppsSheet extends ConsumerStatefulWidget {
  const _WatchedAppsSheet();

  @override
  ConsumerState<_WatchedAppsSheet> createState() => _WatchedAppsSheetState();
}

class _WatchedAppsSheetState extends ConsumerState<_WatchedAppsSheet> {
  bool _refreshing = false;
  String? _refreshError;
  String _searchQuery = '';
  List<InstalledAppCandidate> _candidates = const [];

  Future<void> _refreshSuggestedApps() async {
    setState(() {
      _refreshing = true;
      _refreshError = null;
    });

    try {
      final suggestions = await ref
          .read(androidCapabilityServiceProvider)
          .getInstalledAppCandidates();

      if (mounted && suggestions.isEmpty) {
        setState(() => _refreshError = 'No banking apps found yet.');
      } else if (mounted) {
        setState(() => _candidates = suggestions);
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
              const SizedBox(height: 6),
              Text(
                'Pick the finance apps Kolo should watch. Installed banking apps appear first.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: KoloColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('watched_apps_search'),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search installed apps',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    key: const Key('refresh_watched_apps'),
                    onPressed: _refreshing ? null : _refreshSuggestedApps,
                    icon: _refreshing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    tooltip: 'Refresh apps',
                  ),
                ],
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
                data: (state) {
                  final accessibilityState =
                      state.permissions[KoloPermission.accessibility] ??
                      PermissionGrantState.notRequested;
                  final accessibilityGranted =
                      accessibilityState == PermissionGrantState.granted;
                  final visibleWatchedApps = _filterWatchedApps(
                    state.watchedApps,
                  );
                  final candidateApps = _filterCandidates(state.watchedApps);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WatchedAppsAccessibilityPrompt(
                        state: accessibilityState,
                        onGrant: () async {
                          final permissionState = await ref
                              .read(permissionRequesterProvider)
                              .request(KoloPermission.accessibility);
                          await ref
                              .read(koloRepositoryProvider)
                              .updatePermission(
                                KoloPermission.accessibility,
                                permissionState,
                              );
                        },
                      ),
                      const SizedBox(height: 12),
                      if (visibleWatchedApps.isNotEmpty) ...[
                        Text(
                          'Watching',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                      ],
                      for (final app in visibleWatchedApps)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _WatchedAppToggle(
                            app: app,
                            accessibilityGranted: accessibilityGranted,
                          ),
                        ),
                      if (candidateApps.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Add apps',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        for (final candidate in candidateApps)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _InstalledAppCandidateTile(
                              candidate: candidate,
                            ),
                          ),
                      ],
                      if (visibleWatchedApps.isEmpty &&
                          candidateApps.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.trim().isEmpty
                              ? 'Refresh to discover installed apps.'
                              : 'No apps match your search.',
                          style: const TextStyle(
                            color: KoloColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<WatchedApp> _filterWatchedApps(List<WatchedApp> watchedApps) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return watchedApps;
    return watchedApps.where((app) => _matchesWatchedApp(app, query)).toList();
  }

  List<InstalledAppCandidate> _filterCandidates(List<WatchedApp> watchedApps) {
    final watchedPackages = {
      for (final app in watchedApps) app.packageName.toLowerCase(),
    };
    final query = _searchQuery.trim().toLowerCase();
    return _candidates.where((candidate) {
      if (watchedPackages.contains(candidate.packageName.toLowerCase())) {
        return false;
      }
      if (query.isEmpty) return true;
      return _matchesCandidate(candidate, query);
    }).toList();
  }

  bool _matchesWatchedApp(WatchedApp app, String query) {
    return app.displayName.toLowerCase().contains(query) ||
        app.packageName.toLowerCase().contains(query);
  }

  bool _matchesCandidate(InstalledAppCandidate candidate, String query) {
    return candidate.displayName.toLowerCase().contains(query) ||
        candidate.packageName.toLowerCase().contains(query);
  }
}

class _WatchedAppsAccessibilityPrompt extends StatelessWidget {
  const _WatchedAppsAccessibilityPrompt({
    required this.state,
    required this.onGrant,
  });

  final PermissionGrantState state;
  final Future<void> Function() onGrant;

  @override
  Widget build(BuildContext context) {
    final granted = state == PermissionGrantState.granted;
    return Container(
      key: const Key('watched_apps_accessibility_prompt'),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: KoloColors.primaryPastel,
            child: Icon(
              granted
                  ? Icons.verified_user_outlined
                  : Icons.accessibility_new_outlined,
              color: KoloColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  granted
                      ? 'Accessibility service ready'
                      : 'Enable Accessibility Service',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  granted
                      ? 'Kolo can react when watched banking apps open.'
                      : 'Kolo needs this to detect when a watched banking app comes to the front.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KoloColors.textSecondary,
                  ),
                ),
                if (!granted) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const Key('enable_accessibility_from_watched_apps'),
                    onPressed: onGrant,
                    icon: const Icon(Icons.settings_accessibility, size: 18),
                    label: const Text('Enable'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchedAppToggle extends ConsumerWidget {
  const _WatchedAppToggle({
    required this.app,
    required this.accessibilityGranted,
  });

  final WatchedApp app;
  final bool accessibilityGranted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canChange = accessibilityGranted || app.enabled;
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
      child: Column(
        children: [
          SwitchListTile(
            key: Key('toggle_watched_app_${app.packageName}'),
            value: app.enabled,
            activeThumbColor: KoloColors.primary,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
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
            subtitle: Text(
              app.enabled
                  ? _blockLevelSummary(app.blockLevel)
                  : canChange
                  ? 'Off'
                  : 'Grant Accessibility before enabling',
            ),
            onChanged: canChange
                ? (enabled) async {
                    await _saveWatchedApp(ref, enabled: enabled);
                  }
                : null,
          ),
          if (app.enabled) ...[
            const Divider(height: 1, color: Color(0xFFEDE9FE)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Block Level',
                    style: TextStyle(
                      color: KoloColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final level in WatchedAppBlockLevel.values)
                        ChoiceChip(
                          key: Key(
                            'block_level_${app.packageName}_${level.name}',
                          ),
                          selected: app.blockLevel == level,
                          label: Text(_blockLevelLabel(level)),
                          selectedColor: KoloColors.primaryPastel,
                          backgroundColor: const Color(0xFFF9FAFB),
                          checkmarkColor: KoloColors.primary,
                          labelStyle: TextStyle(
                            color: app.blockLevel == level
                                ? KoloColors.primary
                                : KoloColors.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: app.blockLevel == level
                                ? KoloColors.primaryLight
                                : const Color(0xFFE5E7EB),
                          ),
                          onSelected: (_) async {
                            await _saveWatchedApp(ref, blockLevel: level);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _blockLevelDescription(app.blockLevel),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: KoloColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveWatchedApp(
    WidgetRef ref, {
    bool? enabled,
    WatchedAppBlockLevel? blockLevel,
  }) {
    return ref
        .read(koloRepositoryProvider)
        .upsertWatchedApp(
          WatchedApp(
            packageName: app.packageName,
            displayName: app.displayName,
            enabled: enabled ?? app.enabled,
            blockLevel: blockLevel ?? app.blockLevel,
          ),
        );
  }
}

String _blockLevelLabel(WatchedAppBlockLevel level) {
  return switch (level) {
    WatchedAppBlockLevel.soft => 'Soft',
    WatchedAppBlockLevel.explain => 'Explain',
    WatchedAppBlockLevel.hardLock => 'Hard Lock',
  };
}

String _blockLevelSummary(WatchedAppBlockLevel level) {
  return switch (level) {
    WatchedAppBlockLevel.soft => 'Soft mode',
    WatchedAppBlockLevel.explain => 'Explain mode',
    WatchedAppBlockLevel.hardLock => 'Hard Lock mode',
  };
}

String _blockLevelDescription(WatchedAppBlockLevel level) {
  return switch (level) {
    WatchedAppBlockLevel.soft =>
      'Soft mode - Kolo shows a dismissible bubble when this app opens.',
    WatchedAppBlockLevel.explain =>
      'Explain mode - you must type a reason before Kolo lets you through.',
    WatchedAppBlockLevel.hardLock =>
      'Hard Lock mode - Kolo checks budget context before you proceed.',
  };
}

class _InstalledAppCandidateTile extends ConsumerWidget {
  const _InstalledAppCandidateTile({required this.candidate});

  final InstalledAppCandidate candidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = candidate.installed;
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: candidate.isKnownFinancialApp
              ? KoloColors.primaryPastel
              : const Color(0xFFF3F4F6),
          child: Icon(
            candidate.isKnownFinancialApp
                ? Icons.account_balance_wallet_outlined
                : Icons.apps_outlined,
            color: candidate.isKnownFinancialApp
                ? KoloColors.primary
                : KoloColors.textSecondary,
          ),
        ),
        title: Text(
          candidate.displayName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          installed
              ? candidate.isKnownFinancialApp
                    ? 'Installed finance app'
                    : 'Installed app'
              : 'Suggested finance app',
        ),
        trailing: OutlinedButton(
          key: Key('add_watched_app_${candidate.packageName}'),
          onPressed: installed
              ? () async {
                  await ref
                      .read(koloRepositoryProvider)
                      .upsertWatchedApp(candidate.toWatchedApp());
                }
              : null,
          child: Text(installed ? 'Add' : 'Not installed'),
        ),
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
