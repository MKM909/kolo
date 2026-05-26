import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/money_formatter.dart';

class ReminderPlanBuilder {
  ReminderPlanBuilder._();

  static List<ReminderScheduleIntent> build(
    DashboardState dashboard, {
    DateTime? now,
  }) {
    final anchor = now ?? DateTime.now();
    final preferences = dashboard.profile.notificationPreferences;
    final plans = <ReminderScheduleIntent>[];

    if (preferences.billReminders) {
      for (final bill in dashboard.bills.where((bill) => bill.active)) {
        plans.addAll(_billPlans(bill, anchor));
      }
    }

    if (preferences.billReminders) {
      for (final owing in dashboard.owings.where((owing) => !owing.settled)) {
        final plan = _owingPlan(owing, anchor);
        if (plan != null) plans.add(plan);
      }
    }

    if (preferences.weeklyInsights) {
      plans.add(_weeklyInsightPlan(anchor));
    }

    return plans
        .where((plan) => plan.scheduledAt.isAfter(anchor))
        .toList(growable: false);
  }

  static Iterable<ReminderScheduleIntent> _billPlans(
    BillReminder bill,
    DateTime now,
  ) sync* {
    for (final daysBeforeDue in [3, 1]) {
      final reminderDay = _dateOnly(
        bill.nextDue.subtract(Duration(days: daysBeforeDue)),
      );
      final scheduledAt = DateTime(
        reminderDay.year,
        reminderDay.month,
        reminderDay.day,
        9,
      );
      yield ReminderScheduleIntent.bill(
        billId: bill.id,
        title:
            '$daysBeforeDue day${daysBeforeDue == 1 ? '' : 's'} to ${bill.name}',
        body:
            'Keep ${MoneyFormatter.formatKobo(bill.amountKobo)} ready for ${bill.name}.',
        scheduledAt: scheduledAt,
        daysBeforeDue: daysBeforeDue,
      );
    }
  }

  static ReminderScheduleIntent? _owingPlan(Owing owing, DateTime now) {
    final dueDate = owing.dueDate;
    if (dueDate == null) return null;

    final dueDay = _dateOnly(dueDate);
    final today = _dateOnly(now);
    if (owing.type == OwingType.theyOweMe && dueDay.isBefore(today)) {
      return ReminderScheduleIntent(
        id: 'owing-${owing.id}-overdue',
        title: '${owing.person} still owes you',
        body:
            '${owing.person} owes ${MoneyFormatter.formatKobo(owing.amountKobo)}. Send a gentle Kolo reminder.',
        scheduledAt: DateTime(today.year, today.month, today.day, 12),
        payload: {
          'kind': 'owing',
          'owingId': owing.id,
          'direction': owing.type.name,
        },
      );
    }

    if (owing.type == OwingType.iOweThem && !dueDay.isBefore(today)) {
      return ReminderScheduleIntent(
        id: 'owing-${owing.id}-due',
        title: 'Pay ${owing.person}',
        body:
            '${MoneyFormatter.formatKobo(owing.amountKobo)} is due to ${owing.person}.',
        scheduledAt: DateTime(dueDay.year, dueDay.month, dueDay.day, 9),
        payload: {
          'kind': 'owing',
          'owingId': owing.id,
          'direction': owing.type.name,
        },
      );
    }

    return null;
  }

  static ReminderScheduleIntent _weeklyInsightPlan(DateTime now) {
    final today = _dateOnly(now);
    final daysUntilMonday = (DateTime.monday - today.weekday) % 7;
    final nextMonday = today.add(
      Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday),
    );
    return ReminderScheduleIntent(
      id: 'weekly-insight',
      title: 'Your weekly Kolo insight is ready',
      body: 'Review your spending pattern and choose one small money move.',
      scheduledAt: DateTime(
        nextMonday.year,
        nextMonday.month,
        nextMonday.day,
        9,
      ),
      payload: const {'kind': 'weeklyInsight'},
    );
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
