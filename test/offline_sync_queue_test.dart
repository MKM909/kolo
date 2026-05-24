import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/services/offline_sync_queue.dart';

void main() {
  test('retryPending removes only successfully synced operations', () async {
    final queue = OfflineSyncQueue();
    await queue.enqueue(
      PendingSyncOperation(
        id: 'sync-ok',
        kind: 'transaction',
        payload: const {'amountKobo': 250000},
        createdAt: DateTime(2026, 5, 24),
      ),
    );
    await queue.enqueue(
      PendingSyncOperation(
        id: 'sync-later',
        kind: 'partner_summary',
        payload: const {'shareId': 'share-1'},
        createdAt: DateTime(2026, 5, 24),
      ),
    );

    final synced = await queue.retryPending(
      (operation) async => operation.id == 'sync-ok',
    );
    final pending = await queue.watchPendingOperations().first;

    expect(synced, 1);
    expect(pending.map((operation) => operation.id), ['sync-later']);
  });

  test('retryPending keeps operations that throw during sync', () async {
    final queue = OfflineSyncQueue();
    await queue.enqueue(
      PendingSyncOperation(
        id: 'sync-throws',
        kind: 'transaction',
        payload: const {'amountKobo': 250000},
        createdAt: DateTime(2026, 5, 24),
      ),
    );

    final synced = await queue.retryPending((operation) async {
      throw StateError('offline');
    });
    final pending = await queue.watchPendingOperations().first;

    expect(synced, 0);
    expect(pending.single.id, 'sync-throws');
  });

  test('pending operations survive queue recreation with the same store', () async {
    final store = MemoryOfflineSyncStore();
    final firstQueue = OfflineSyncQueue(store: store);
    await firstQueue.enqueue(
      PendingSyncOperation(
        id: 'sync-persisted',
        kind: 'transaction',
        payload: const {'amountKobo': 250000},
        createdAt: DateTime(2026, 5, 24),
      ),
    );

    final secondQueue = OfflineSyncQueue(store: store);
    final pending = await secondQueue.watchPendingOperations().first;

    expect(pending.single.id, 'sync-persisted');
    expect(pending.single.payload['amountKobo'], 250000);
  });
}
