import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/services/reminder_sync_service.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/reminder_scheduler.dart';

void main() {
  test(
    'schedules planned reminders when notification permission is granted',
    () async {
      final scheduler = _FakeReminderScheduler();
      final dashboard = _dashboard(
        bills: [
          BillReminder(
            id: 'bill-data',
            name: 'Data renewal',
            amountKobo: 250000,
            frequency: 'monthly',
            nextDue: DateTime(2026, 5, 30),
          ),
        ],
      );

      final count = await ReminderSyncService(
        scheduler: scheduler,
      ).sync(dashboard, now: DateTime(2026, 5, 26, 9));

      expect(count, 3);
      expect(
        scheduler.scheduled.map((intent) => intent.id),
        containsAll([
          'bill-bill-data-3d',
          'bill-bill-data-1d',
          'weekly-insight',
        ]),
      );
    },
  );

  test('cancels reminders when notifications are denied', () async {
    final scheduler = _FakeReminderScheduler();
    final dashboard = _dashboard(
      permissions: const {
        KoloPermission.notifications: PermissionGrantState.denied,
      },
    );

    final count = await ReminderSyncService(
      scheduler: scheduler,
    ).sync(dashboard, now: DateTime(2026, 5, 26, 9));

    expect(count, 0);
    expect(scheduler.scheduled, isEmpty);
    expect(
      scheduler.cancelled,
      containsAll(['weekly-insight', 'bill-reminders', 'owing-reminders']),
    );
  });
}

class _FakeReminderScheduler implements ReminderScheduler {
  final scheduled = <ReminderScheduleIntent>[];
  final cancelled = <String>[];

  @override
  Future<void> schedule(ReminderScheduleIntent intent) async {
    scheduled.add(intent);
  }

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
  }
}

DashboardState _dashboard({
  List<BillReminder> bills = const [],
  Map<KoloPermission, PermissionGrantState> permissions = const {
    KoloPermission.notifications: PermissionGrantState.granted,
  },
}) {
  return DashboardState(
    profile: UserProfile(
      uid: 'uid',
      name: 'Kolo User',
      email: 'user@example.com',
      createdAt: DateTime(2026, 1, 1),
    ),
    balanceKobo: 5000000,
    balanceAdjustments: const [],
    budgetPlan: const BudgetPlan(
      monthlyIncomeKobo: 0,
      incomeType: 'irregular',
      categories: [],
      savingsTargetKobo: 0,
      savingsGoal: 'Buffer',
      aiNotes: '',
    ),
    transactions: const [],
    aiMessages: const [],
    vaults: const [],
    owings: const [],
    gigs: const [],
    bills: bills,
    watchedApps: const [],
    partnerShares: const [],
    insights: const [],
    permissions: permissions,
  );
}
