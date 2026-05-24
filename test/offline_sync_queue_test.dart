import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
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

  test('Hive store persists pending operations across reopened boxes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'kolo_offline_sync_',
    );
    Hive.init(directory.path);
    var box = await Hive.openBox<Object?>('sync_queue_test');
    addTearDown(() async {
      if (Hive.isBoxOpen('sync_queue_test')) {
        await Hive.box<Object?>('sync_queue_test').close();
      }
      await Hive.deleteBoxFromDisk('sync_queue_test');
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final firstQueue = OfflineSyncQueue(store: HiveOfflineSyncStore(box));
    await firstQueue.enqueue(
      PendingSyncOperation(
        id: 'sync-hive',
        kind: 'bill',
        payload: const {'billId': 'bill-data'},
        createdAt: DateTime(2026, 5, 24, 15),
      ),
    );

    await box.close();
    box = await Hive.openBox<Object?>('sync_queue_test');
    final secondQueue = OfflineSyncQueue(store: HiveOfflineSyncStore(box));
    final pending = await secondQueue.watchPendingOperations().first;

    expect(pending.single.id, 'sync-hive');
    expect(pending.single.kind, 'bill');
    expect(pending.single.payload['billId'], 'bill-data');
  });
}
