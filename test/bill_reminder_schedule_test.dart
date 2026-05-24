import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/bill_reminder_schedule.dart';

void main() {
  group('BillReminderSchedule', () {
    test(
      'classifies paused, overdue, due today, due soon, and upcoming bills',
      () {
        final now = DateTime(2026, 5, 24, 10);

        expect(
          BillReminderSchedule.statusFor(
            BillReminder(
              id: 'paused',
              name: 'Paused',
              amountKobo: 100000,
              frequency: 'monthly',
              nextDue: DateTime(2026, 5, 24),
              active: false,
            ),
            now: now,
          ).label,
          'Paused',
        );

        expect(
          BillReminderSchedule.statusFor(
            BillReminder(
              id: 'overdue',
              name: 'Data',
              amountKobo: 100000,
              frequency: 'monthly',
              nextDue: DateTime(2026, 5, 22),
            ),
            now: now,
          ).label,
          'Overdue by 2 days',
        );

        expect(
          BillReminderSchedule.statusFor(
            BillReminder(
              id: 'today',
              name: 'Electricity',
              amountKobo: 100000,
              frequency: 'monthly',
              nextDue: DateTime(2026, 5, 24),
            ),
            now: now,
          ).label,
          'Due today',
        );

        expect(
          BillReminderSchedule.statusFor(
            BillReminder(
              id: 'soon',
              name: 'Wifi',
              amountKobo: 100000,
              frequency: 'monthly',
              nextDue: DateTime(2026, 5, 27),
            ),
            now: now,
          ).label,
          'Due in 3 days',
        );

        expect(
          BillReminderSchedule.statusFor(
            BillReminder(
              id: 'later',
              name: 'Hostel',
              amountKobo: 100000,
              frequency: 'quarterly',
              nextDue: DateTime(2026, 6, 10),
            ),
            now: now,
          ).urgency,
          BillReminderUrgency.upcoming,
        );
      },
    );

    test('advances recurring bills to the next future due date', () {
      final now = DateTime(2026, 5, 24, 10);

      expect(
        BillReminderSchedule.nextDueAfter(
          DateTime(2026, 5, 27),
          'monthly',
          now: now,
        ),
        DateTime(2026, 6, 27),
      );
      expect(
        BillReminderSchedule.nextDueAfter(
          DateTime(2026, 3, 1),
          'monthly',
          now: now,
        ),
        DateTime(2026, 6, 1),
      );
      expect(
        BillReminderSchedule.nextDueAfter(
          DateTime(2026, 5, 17),
          'weekly',
          now: now,
        ),
        DateTime(2026, 5, 31),
      );
      expect(
        BillReminderSchedule.nextDueAfter(
          DateTime(2025, 5, 1),
          'yearly',
          now: now,
        ),
        DateTime(2027, 5, 1),
      );
    });

    test('returns three-day and one-day reminder moments', () {
      final bill = BillReminder(
        id: 'data',
        name: 'Data',
        amountKobo: 100000,
        frequency: 'monthly',
        nextDue: DateTime(2026, 5, 24, 9),
      );

      expect(BillReminderSchedule.reminderMoments(bill), [
        DateTime(2026, 5, 21, 9),
        DateTime(2026, 5, 23, 9),
      ]);
    });
  });
}
