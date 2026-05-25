import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/repositories/fake_kolo_repository.dart';
import 'package:kolo/data/services/due_bill_processor.dart';
import 'package:kolo/domain/models/models.dart';

void main() {
  test(
    'processes due active bills as idempotent expense transactions',
    () async {
      final repository = FakeKoloRepository.seeded();
      final initial = await repository.watchDashboard().first;
      final now = DateTime(2026, 5, 24);

      await repository.upsertBill(
        BillReminder(
          id: 'bill-wifi',
          name: 'Wifi',
          amountKobo: 1000000,
          frequency: 'Monthly',
          nextDue: DateTime(2026, 5, 20),
        ),
      );

      final processor = DueBillProcessor(repository: repository);
      final processed = await processor.process(now: now);

      expect(processed, 1);

      final dashboard = await repository.watchDashboard().first;
      expect(dashboard.balanceKobo, initial.balanceKobo - 1000000);
      expect(
        dashboard.transactions.firstWhere(
          (tx) => tx.id == 'bill-paid-bill-wifi-2026-05-20',
        ),
        isA<TransactionRecord>()
            .having((tx) => tx.description, 'description', 'Wifi paid')
            .having((tx) => tx.category, 'category', 'Utilities & Bills'),
      );
      expect(
        dashboard.bills.firstWhere((bill) => bill.id == 'bill-wifi').nextDue,
        DateTime(2026, 6, 20),
      );

      final processedAgain = await processor.process(now: now);

      expect(processedAgain, 0);
    },
  );
}
