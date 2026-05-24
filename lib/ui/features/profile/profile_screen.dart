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
  const _ProfileSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: KoloCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
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
