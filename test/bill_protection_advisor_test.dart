import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/bill_protection_advisor.dart';

void main() {
  test('warns when spending leaves too little for bills due soon', () {
    final now = DateTime(2026, 5, 24);
    final warning = BillProtectionAdvisor.check(
      balanceKobo: 2000000,
      expenseKobo: 300000,
      now: now,
      bills: [
        BillReminder(
          id: 'bill-data',
          name: 'Data renewal',
          amountKobo: 1800000,
          frequency: 'Monthly',
          nextDue: now.add(const Duration(days: 2)),
        ),
        BillReminder(
          id: 'bill-hostel',
          name: 'Hostel dues',
          amountKobo: 5000000,
          frequency: 'Quarterly',
          nextDue: now.add(const Duration(days: 12)),
        ),
      ],
    );

    expect(warning.risksDueBills, isTrue);
    expect(warning.reservedKobo, 1800000);
    expect(warning.shortfallKobo, 100000);
    expect(warning.primaryBillName, 'Data renewal');

    final inactiveBill = BillProtectionAdvisor.check(
      balanceKobo: 2000000,
      expenseKobo: 300000,
      now: now,
      bills: [
        BillReminder(
          id: 'bill-paused',
          name: 'Paused data',
          amountKobo: 1800000,
          frequency: 'Monthly',
          nextDue: now.add(const Duration(days: 1)),
          active: false,
        ),
      ],
    );

    expect(inactiveBill.risksDueBills, isFalse);
  });
}
