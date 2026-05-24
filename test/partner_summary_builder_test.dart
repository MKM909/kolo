import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/repositories/fake_kolo_repository.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/partner_summary_builder.dart';

void main() {
  test('builds only the partner-approved summary sections', () async {
    final state = await FakeKoloRepository.seeded().watchDashboard().first;
    final share = state.partnerShares.first;

    final summary = PartnerSummaryBuilder.build(
      dashboard: state,
      share: share,
      generatedAt: DateTime(2026, 5, 24, 20),
    );

    expect(summary, isNotNull);
    expect(summary!.shareId, share.id);
    expect(summary.partnerEmail, share.partnerEmail);
    expect(summary.sections.keys, contains('balance_summary'));
    expect(summary.sections.keys, contains('budget_summary'));
    expect(summary.sections.keys, contains('weekly_insights'));
    expect(summary.sections.keys, isNot(contains('vault_goals')));
    expect(summary.sections.keys, isNot(contains('owings')));
    expect(summary.sections.keys, isNot(contains('bills')));
  });

  test('does not expose raw transaction or owing identities', () async {
    final state = await FakeKoloRepository.seeded().watchDashboard().first;
    final share = PartnerShare(
      id: 'share-safe',
      partnerEmail: 'safe@example.com',
      status: ShareStatus.active,
      permissions: const {
        'balance_summary',
        'budget_summary',
        'vault_goals',
        'owings',
        'bills',
        'weekly_insights',
      },
      createdAt: DateTime(2026, 5, 24),
    );

    final summary = PartnerSummaryBuilder.build(
      dashboard: state,
      share: share,
      generatedAt: DateTime(2026, 5, 24, 20),
    );

    final serialized = summary!.toJson().toString();

    expect(serialized, isNot(contains('Chicken Republic')));
    expect(serialized, isNot(contains('Timi')));
    expect(serialized, isNot(contains('Ada')));
    expect(serialized, isNot(contains('tx-food')));
  });

  test('does not build summaries for inactive partner shares', () async {
    final state = await FakeKoloRepository.seeded().watchDashboard().first;
    final share = PartnerShare(
      id: 'share-revoked',
      partnerEmail: 'revoked@example.com',
      status: ShareStatus.revoked,
      permissions: const {'balance_summary'},
      createdAt: DateTime(2026, 5, 24),
      revokedAt: DateTime(2026, 5, 25),
    );

    final summary = PartnerSummaryBuilder.build(
      dashboard: state,
      share: share,
      generatedAt: DateTime(2026, 5, 24, 20),
    );

    expect(summary, isNull);
  });
}
