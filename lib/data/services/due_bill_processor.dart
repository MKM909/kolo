import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';
import 'package:kolo/domain/services/bill_reminder_schedule.dart';
import 'package:kolo/domain/services/money_formatter.dart';

class DueBillProcessor {
  const DueBillProcessor({required KoloRepository repository})
    : _repository = repository;

  final KoloRepository _repository;

  Future<int> process({DateTime? now}) async {
    final anchor = now ?? DateTime.now();
    final dashboard = await _repository.watchDashboard().first;
    var processed = 0;

    for (final bill in dashboard.bills) {
      if (!_isDueForAutoDeduction(bill, anchor)) continue;

      await _repository.logTransaction(
        TransactionRecord.expense(
          id: 'bill-paid-${bill.id}-${_dateKey(bill.nextDue)}',
          amountKobo: bill.amountKobo,
          category: 'Utilities & Bills',
          description: '${bill.name} paid',
          date: bill.nextDue,
          source: TransactionSource.manual,
          merchantName: bill.name,
          aiApproved: true,
          aiNote:
              'Auto-deducted when the bill became due for ${MoneyFormatter.formatKobo(bill.amountKobo)}.',
        ),
      );
      await _repository.upsertBill(
        BillReminder(
          id: bill.id,
          name: bill.name,
          amountKobo: bill.amountKobo,
          frequency: bill.frequency,
          nextDue: BillReminderSchedule.nextDueAfter(
            bill.nextDue,
            bill.frequency,
            now: anchor,
          ),
          active: bill.active,
        ),
      );
      processed += 1;
    }

    return processed;
  }

  bool _isDueForAutoDeduction(BillReminder bill, DateTime now) {
    if (!bill.active) return false;
    final status = BillReminderSchedule.statusFor(bill, now: now);
    return status.urgency == BillReminderUrgency.overdue ||
        status.urgency == BillReminderUrgency.dueToday;
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
