import 'package:kolo/domain/models/models.dart';

enum BillReminderUrgency { paused, overdue, dueToday, dueSoon, upcoming }

class BillReminderStatus {
  const BillReminderStatus({
    required this.urgency,
    required this.daysUntilDue,
    required this.label,
  });

  final BillReminderUrgency urgency;
  final int daysUntilDue;
  final String label;
}

class BillReminderSchedule {
  BillReminderSchedule._();

  static BillReminderStatus statusFor(BillReminder bill, {DateTime? now}) {
    if (!bill.active) {
      return const BillReminderStatus(
        urgency: BillReminderUrgency.paused,
        daysUntilDue: 0,
        label: 'Paused',
      );
    }

    final daysUntilDue = _daysUntil(bill.nextDue, now ?? DateTime.now());
    if (daysUntilDue < 0) {
      final daysOverdue = -daysUntilDue;
      return BillReminderStatus(
        urgency: BillReminderUrgency.overdue,
        daysUntilDue: daysUntilDue,
        label: 'Overdue by ${_dayLabel(daysOverdue)}',
      );
    }
    if (daysUntilDue == 0) {
      return const BillReminderStatus(
        urgency: BillReminderUrgency.dueToday,
        daysUntilDue: 0,
        label: 'Due today',
      );
    }
    if (daysUntilDue <= 3) {
      return BillReminderStatus(
        urgency: BillReminderUrgency.dueSoon,
        daysUntilDue: daysUntilDue,
        label: 'Due in ${_dayLabel(daysUntilDue)}',
      );
    }
    return BillReminderStatus(
      urgency: BillReminderUrgency.upcoming,
      daysUntilDue: daysUntilDue,
      label: 'Due in ${_dayLabel(daysUntilDue)}',
    );
  }

  static DateTime nextDueAfter(
    DateTime currentDue,
    String frequency, {
    DateTime? now,
  }) {
    final anchor = _dateOnly(now ?? DateTime.now());
    var nextDue = _advance(currentDue, frequency);
    while (!_dateOnly(nextDue).isAfter(anchor)) {
      nextDue = _advance(nextDue, frequency);
    }
    return nextDue;
  }

  static List<DateTime> reminderMoments(BillReminder bill) {
    return [
      bill.nextDue.subtract(const Duration(days: 3)),
      bill.nextDue.subtract(const Duration(days: 1)),
    ];
  }

  static List<BillReminder> dueSoon(
    List<BillReminder> bills, {
    DateTime? now,
    int windowDays = 3,
  }) {
    final anchor = now ?? DateTime.now();
    return bills
        .where((bill) {
          if (!bill.active) return false;
          final days = _daysUntil(bill.nextDue, anchor);
          return days <= windowDays;
        })
        .toList(growable: false);
  }

  static DateTime _advance(DateTime currentDue, String frequency) {
    final normalized = frequency.toLowerCase();
    if (normalized.contains('week')) {
      return currentDue.add(const Duration(days: 7));
    }
    if (normalized.contains('year') || normalized.contains('annual')) {
      return DateTime(currentDue.year + 1, currentDue.month, currentDue.day);
    }
    if (normalized.contains('quarter')) {
      return DateTime(currentDue.year, currentDue.month + 3, currentDue.day);
    }
    if (normalized.contains('day')) {
      return currentDue.add(const Duration(days: 1));
    }
    return DateTime(currentDue.year, currentDue.month + 1, currentDue.day);
  }

  static int _daysUntil(DateTime value, DateTime now) {
    return _dateOnly(value).difference(_dateOnly(now)).inDays;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String _dayLabel(int days) {
    return days == 1 ? '1 day' : '$days days';
  }
}
