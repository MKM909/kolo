import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/reminder_plan_builder.dart';

void main() {
  test('plans bill reminders three days and one day before due date', () {
    final plans = ReminderPlanBuilder.build(
      _dashboard(
        bills: [
          BillReminder(
            id: 'bill-data',
            name: 'Data renewal',
            amountKobo: 250000,
            frequency: 'monthly',
            nextDue: DateTime(2026, 5, 30, 18),
          ),
        ],
      ),
      now: DateTime(2026, 5, 26, 9),
    );

    expect(
      plans.map((plan) => plan.id),
      containsAll(['bill-bill-data-3d', 'bill-bill-data-1d']),
    );
    expect(
      plans.firstWhere((plan) => plan.id == 'bill-bill-data-3d').scheduledAt,
      DateTime(2026, 5, 27, 9),
    );
    expect(
      plans.firstWhere((plan) => plan.id == 'bill-bill-data-1d').scheduledAt,
      DateTime(2026, 5, 29, 9),
    );
  });

  test('skips paused bills and disabled notification preferences', () {
    final plans = ReminderPlanBuilder.build(
      _dashboard(
        profile: _profile(
          preferences: const NotificationPreferences(
            billReminders: false,
            weeklyInsights: false,
          ),
        ),
        bills: [
          BillReminder(
            id: 'paused',
            name: 'Paused plan',
            amountKobo: 120000,
            frequency: 'weekly',
            nextDue: DateTime(2026, 5, 30),
            active: false,
          ),
        ],
      ),
      now: DateTime(2026, 5, 26, 9),
    );

    expect(plans, isEmpty);
  });

  test('plans owing and weekly insight reminders when enabled', () {
    final plans = ReminderPlanBuilder.build(
      _dashboard(
        owings: [
          Owing(
            id: 'owe-me',
            type: OwingType.theyOweMe,
            person: 'Ada',
            amountKobo: 700000,
            date: DateTime(2026, 5, 20),
            dueDate: DateTime(2026, 5, 25),
          ),
          Owing(
            id: 'i-owe',
            type: OwingType.iOweThem,
            person: 'Timi',
            amountKobo: 300000,
            date: DateTime(2026, 5, 20),
            dueDate: DateTime(2026, 5, 28),
          ),
        ],
      ),
      now: DateTime(2026, 5, 26, 10),
    );

    expect(
      plans.map((plan) => plan.id),
      containsAll([
        'owing-owe-me-overdue',
        'owing-i-owe-due',
        'weekly-insight',
      ]),
    );
    expect(
      plans.firstWhere((plan) => plan.id == 'owing-owe-me-overdue').scheduledAt,
      DateTime(2026, 5, 26, 12),
    );
    expect(
      plans.firstWhere((plan) => plan.id == 'owing-i-owe-due').scheduledAt,
      DateTime(2026, 5, 28, 9),
    );
    expect(
      plans.firstWhere((plan) => plan.id == 'weekly-insight').scheduledAt,
      DateTime(2026, 6, 1, 9),
    );
  });
}

DashboardState _dashboard({
  UserProfile? profile,
  List<BillReminder> bills = const [],
  List<Owing> owings = const [],
}) {
  return DashboardState(
    profile: profile ?? _profile(),
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
    owings: owings,
    gigs: const [],
    bills: bills,
    watchedApps: const [],
    partnerShares: const [],
    insights: const [],
    permissions: const {
      KoloPermission.notifications: PermissionGrantState.granted,
    },
  );
}

UserProfile _profile({NotificationPreferences? preferences}) {
  return UserProfile(
    uid: 'uid',
    name: 'Kolo User',
    email: 'user@example.com',
    createdAt: DateTime(2026, 1, 1),
    notificationPreferences: preferences ?? const NotificationPreferences(),
  );
}
