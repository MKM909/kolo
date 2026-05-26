import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/partner_repository.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/core/widgets/kolo_scaffold.dart';

class PartnerInviteScreen extends ConsumerStatefulWidget {
  const PartnerInviteScreen({required this.invite, super.key});

  final PartnerInviteRef? invite;

  @override
  ConsumerState<PartnerInviteScreen> createState() =>
      _PartnerInviteScreenState();
}

class _PartnerInviteScreenState extends ConsumerState<PartnerInviteScreen> {
  bool _accepting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    return KoloGradientScaffold(
      title: 'Partner invite',
      child: ListView(
        key: const Key('partner_invite_screen'),
        padding: const EdgeInsets.all(20),
        children: [
          KoloCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: KoloColors.primaryPastel,
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: KoloColors.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Review Kolo invite',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  invite == null
                      ? 'This partner link is incomplete.'
                      : 'You were invited to view partner-safe money summaries. No transaction-level details are shared here.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: KoloColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: KoloColors.expense),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  key: const Key('accept_partner_invite'),
                  onPressed: invite == null || _accepting
                      ? null
                      : () => _accept(invite),
                  child: _accepting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Accept invite'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _accept(PartnerInviteRef invite) async {
    setState(() {
      _accepting = true;
      _error = null;
    });
    try {
      await ref.read(partnerRepositoryProvider).acceptPartnerShare(invite);
      if (!mounted) return;
      context.go(
        '/partner/dashboard?ownerUid=${Uri.encodeComponent(invite.ownerUid)}&shareId=${Uri.encodeComponent(invite.shareId)}',
      );
    } on Object {
      if (mounted) {
        setState(() => _error = 'Kolo could not accept this invite yet.');
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }
}

class PartnerDashboardScreen extends ConsumerWidget {
  const PartnerDashboardScreen({required this.invite, super.key});

  final PartnerInviteRef? invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invite = this.invite;
    if (invite == null) {
      return const KoloGradientScaffold(
        title: 'Partner Dashboard',
        child: Center(
          child: Text('This partner dashboard link is incomplete.'),
        ),
      );
    }

    return KoloGradientScaffold(
      title: 'Partner Dashboard',
      child: StreamBuilder<PartnerSafeSummary?>(
        stream: ref
            .watch(partnerRepositoryProvider)
            .watchPartnerSummary(invite),
        builder: (context, snapshot) {
          final summary = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (summary == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No active partner summary is available yet.'),
              ),
            );
          }
          return ListView(
            key: const Key('partner_dashboard_screen'),
            padding: const EdgeInsets.all(20),
            children: [
              KoloCard(
                color: KoloColors.surfaceDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Partner-safe summary',
                      style: TextStyle(
                        color: KoloColors.textOnDarkMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary.partnerEmail,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (final entry in summary.sections.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PartnerSummarySection(
                    title: _sectionTitle(entry.key),
                    value: entry.value,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PartnerSummarySection extends StatelessWidget {
  const _PartnerSummarySection({required this.title, required this.value});

  final String title;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final map = value is Map ? value as Map : const {};
    return KoloCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (map.containsKey('balanceKobo'))
            Text(
              MoneyFormatter.formatKobo(_int(map['balanceKobo'])),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          for (final entry in map.entries)
            if (entry.key != 'categories' && entry.key != 'balanceKobo')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _SummaryMetric(
                  label: _metricLabel(entry.key.toString()),
                  value: entry.value,
                ),
              ),
          if (map['categories'] is Iterable) ...[
            const SizedBox(height: 8),
            for (final category in (map['categories'] as Iterable))
              if (category is Map)
                _SummaryMetric(
                  label: category['name']?.toString() ?? 'Category',
                  value: category['spentKobo'],
                ),
          ],
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final display = value is num
        ? MoneyFormatter.formatKobo((value as num).toInt())
        : value.toString();
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: KoloColors.textSecondary),
          ),
        ),
        Text(display, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

String _sectionTitle(String key) {
  return switch (key) {
    'balance_summary' => 'Balance summary',
    'budget_summary' => 'Budget summary',
    'vault_goals' => 'Vault goals',
    'owings' => 'Owings summary',
    'bills' => 'Bills summary',
    'weekly_insights' => 'Weekly insights',
    _ => key,
  };
}

String _metricLabel(String key) {
  return key
      .replaceAll(RegExp('Kobo\$'), '')
      .replaceAll('_', ' ')
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) {
        return '${match.group(1)} ${match.group(2)}';
      });
}

int _int(Object? value) {
  return switch (value) {
    final int amount => amount,
    final num amount => amount.toInt(),
    _ => 0,
  };
}
