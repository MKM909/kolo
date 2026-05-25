import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/bill_reminder_schedule.dart';

class BillProtectionAdvisor {
  BillProtectionAdvisor._();

  static BillProtectionWarning check({
    required int balanceKobo,
    required int expenseKobo,
    required List<BillReminder> bills,
    DateTime? now,
  }) {
    final anchor = now ?? DateTime.now();
    final protectedBills = bills
        .where((bill) => _shouldProtect(bill, anchor))
        .toList(growable: false);
    final reservedKobo = protectedBills.fold<int>(
      0,
      (total, bill) => total + bill.amountKobo,
    );
    final balanceAfter = balanceKobo - expenseKobo;
    final risksDueBills =
        reservedKobo > 0 &&
        balanceKobo > reservedKobo &&
        balanceAfter < reservedKobo;

    return BillProtectionWarning(
      risksDueBills: risksDueBills,
      reservedKobo: reservedKobo,
      shortfallKobo: risksDueBills ? reservedKobo - balanceAfter : 0,
      primaryBillName: _primaryBillName(protectedBills, anchor),
    );
  }

  static bool _shouldProtect(BillReminder bill, DateTime now) {
    final status = BillReminderSchedule.statusFor(bill, now: now);
    return switch (status.urgency) {
      BillReminderUrgency.overdue ||
      BillReminderUrgency.dueToday ||
      BillReminderUrgency.dueSoon => true,
      BillReminderUrgency.paused || BillReminderUrgency.upcoming => false,
    };
  }

  static String? _primaryBillName(List<BillReminder> bills, DateTime now) {
    BillReminder? primary;
    BillReminderStatus? primaryStatus;
    for (final bill in bills) {
      final status = BillReminderSchedule.statusFor(bill, now: now);
      if (primary == null ||
          status.daysUntilDue < primaryStatus!.daysUntilDue) {
        primary = bill;
        primaryStatus = status;
      }
    }
    return primary?.name;
  }
}

class BillProtectionWarning {
  const BillProtectionWarning({
    required this.risksDueBills,
    required this.reservedKobo,
    required this.shortfallKobo,
    this.primaryBillName,
  });

  final bool risksDueBills;
  final int reservedKobo;
  final int shortfallKobo;
  final String? primaryBillName;
}
