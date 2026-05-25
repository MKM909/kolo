import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/repositories/fake_kolo_repository.dart';
import 'package:kolo/data/services/offline_sync_dispatcher.dart';
import 'package:kolo/data/services/offline_sync_queue.dart';
import 'package:kolo/domain/models/models.dart';

void main() {
  test('retryPending logs queued transactions and marks them synced', () async {
    final repository = FakeKoloRepository.seeded();
    final queue = OfflineSyncQueue();
    await queue.enqueue(
      PendingSyncOperation(
        id: 'offline-transaction',
        kind: 'transaction',
        payload: {
          'id': 'tx-offline-1',
          'amountKobo': 325000,
          'type': 'expense',
          'category': 'Food',
          'description': 'Dinner while offline',
          'date': DateTime(2026, 5, 24, 19).toIso8601String(),
          'source': 'manual',
          'merchantName': 'Chicken Republic',
          'aiApproved': false,
          'aiNote': 'User confirmed after warning.',
        },
        createdAt: DateTime(2026, 5, 24, 19),
      ),
    );

    final synced = await OfflineSyncDispatcher(
      queue: queue,
      repository: repository,
    ).retryPending();
    final pending = await queue.watchPendingOperations().first;
    final dashboard = await repository.watchDashboard().first;
    final transaction = dashboard.transactions.firstWhere(
      (transaction) => transaction.id == 'tx-offline-1',
    );

    expect(synced, 1);
    expect(pending, isEmpty);
    expect(transaction.amountKobo, 325000);
    expect(transaction.type, TransactionType.expense);
    expect(transaction.source, TransactionSource.manual);
    expect(transaction.aiApproved, isFalse);
  });

  test('retryPending keeps unsupported operations queued', () async {
    final repository = FakeKoloRepository.seeded();
    final queue = OfflineSyncQueue();
    await queue.enqueue(
      PendingSyncOperation(
        id: 'offline-unknown',
        kind: 'mystery',
        payload: const {'id': 'unknown'},
        createdAt: DateTime(2026, 5, 24),
      ),
    );

    final synced = await OfflineSyncDispatcher(
      queue: queue,
      repository: repository,
    ).retryPending();
    final pending = await queue.watchPendingOperations().first;

    expect(synced, 0);
    expect(pending.single.id, 'offline-unknown');
  });
}
