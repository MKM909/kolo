import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/partner_repository.dart';
import 'package:kolo/domain/services/dashboard_cache_store.dart';
import 'package:kolo/domain/services/native_event_queue_store.dart';
import 'package:kolo/domain/services/reminder_scheduler.dart';
import 'package:kolo/domain/services/spending_justification_advisor.dart';

void main() {
  test('spending justification decisions expose launch-safe statuses', () {
    const decision = SpendingJustificationDecision(
      status: SpendingDecisionStatus.caution,
      message: 'You can do this, but it will tighten food this week.',
      aiNote: 'Caution - food budget is already above 80%.',
    );

    expect(decision.approved, isFalse);
    expect(decision.requiresOverride, isTrue);
    expect(decision.toJson(), {
      'status': 'caution',
      'message': 'You can do this, but it will tighten food this week.',
      'aiNote': 'Caution - food budget is already above 80%.',
    });
    expect(
      SpendingJustificationDecision.fromJson({
        'status': 'advisedAgainst',
        'message': 'I would skip this.',
        'aiNote': 'Advised against - bill is due soon.',
      }).status,
      SpendingDecisionStatus.advisedAgainst,
    );
  });

  test('partner invite refs round-trip Kolo deep links', () {
    const invite = PartnerInviteRef(ownerUid: 'owner-1', shareId: 'share-2');

    expect(
      invite.deepLink.toString(),
      'kolo://app/partner/invite?ownerUid=owner-1&shareId=share-2',
    );
    expect(PartnerInviteRef.fromUri(invite.deepLink), invite);
    expect(
      PartnerInviteRef.fromUri(
        Uri.parse('/partner/invite?ownerUid=owner-1&shareId=share-2'),
      ),
      invite,
    );
    expect(PartnerInviteRef.fromUri(Uri.parse('kolo://app/ai')), isNull);
  });

  test('installed app candidates flag banking apps before generic apps', () {
    const kuda = InstalledAppCandidate(
      packageName: 'com.kuda.android',
      displayName: 'Kuda',
      installed: true,
      isKnownFinancialApp: true,
    );
    const calculator = InstalledAppCandidate(
      packageName: 'com.android.calculator2',
      displayName: 'Calculator',
      installed: true,
    );

    expect(kuda.sortRank, lessThan(calculator.sortRank));
    expect(kuda.toWatchedApp().enabled, isFalse);
  });

  test('reminder schedule intents produce stable notification ids', () {
    final intent = ReminderScheduleIntent.bill(
      billId: 'bill-data',
      title: 'Data renews soon',
      body: 'MTN data is due in 3 days.',
      scheduledAt: DateTime(2026, 5, 30, 9),
      daysBeforeDue: 3,
    );

    expect(intent.id, 'bill-bill-data-3d');
    expect(intent.payload['kind'], 'bill');
    expect(intent.payload['billId'], 'bill-data');
  });

  test(
    'missing feature service interfaces compile against stable contracts',
    () {
      expect(_FakeSpendingAdvisor(), isA<SpendingJustificationAdvisor>());
      expect(_FakePartnerRepository(), isA<PartnerRepository>());
      expect(_FakeReminderScheduler(), isA<ReminderScheduler>());
      expect(_FakeDashboardCacheStore(), isA<DashboardCacheStore>());
      expect(_FakeNativeEventQueueStore(), isA<NativeEventQueueStore>());
    },
  );
}

class _FakeSpendingAdvisor implements SpendingJustificationAdvisor {
  @override
  Future<SpendingJustificationDecision> evaluateSpendingJustification({
    required DashboardState context,
    required TransactionRecord transaction,
    required String justification,
    String? modelName,
  }) async {
    return const SpendingJustificationDecision(
      status: SpendingDecisionStatus.approved,
      message: 'Approved.',
      aiNote: 'Approved by fake advisor.',
    );
  }
}

class _FakePartnerRepository implements PartnerRepository {
  @override
  Future<PartnerShare> acceptPartnerShare(PartnerInviteRef invite) async {
    return PartnerShare(
      id: invite.shareId,
      partnerEmail: 'partner@kolo.app',
      status: ShareStatus.active,
      permissions: const {'balance_summary'},
      createdAt: DateTime(2026, 5, 26),
    );
  }

  @override
  Stream<PartnerSafeSummary?> watchPartnerSummary(PartnerInviteRef invite) {
    return const Stream.empty();
  }
}

class _FakeReminderScheduler implements ReminderScheduler {
  @override
  Future<void> cancel(String id) async {}

  @override
  Future<void> schedule(ReminderScheduleIntent intent) async {}
}

class _FakeDashboardCacheStore implements DashboardCacheStore {
  @override
  Future<void> clear(String uid) async {}

  @override
  Future<CachedDashboardEntry?> load(String uid) async => null;

  @override
  Future<void> save({
    required String uid,
    required DashboardState dashboard,
    required CachedDashboardMetadata metadata,
  }) async {}
}

class _FakeNativeEventQueueStore implements NativeEventQueueStore {
  @override
  Future<void> append(NativeAndroidEvent event) async {}

  @override
  Future<List<NativeAndroidEvent>> drain() async => const [];

  @override
  Future<List<NativeAndroidEvent>> peek() async => const [];
}
