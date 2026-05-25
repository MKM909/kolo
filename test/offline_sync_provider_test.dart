import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/data/repositories/fake_kolo_repository.dart';
import 'package:kolo/data/services/offline_sync_queue.dart';
import 'package:kolo/domain/models/models.dart';

void main() {
  test('pending sync provider exposes queued operations', () async {
    final queue = OfflineSyncQueue();
    await queue.enqueue(
      PendingSyncOperation(
        id: 'pending-transaction',
        kind: 'transaction',
        payload: const {'amountKobo': 125000},
        createdAt: DateTime(2026, 5, 24, 12),
      ),
    );

    final container = ProviderContainer(
      overrides: [offlineSyncQueueProvider.overrideWithValue(queue)],
    );
    addTearDown(container.dispose);

    final subscription = container.listen<
      AsyncValue<List<PendingSyncOperation>>
    >(pendingSyncOperationsProvider, (_, _) {}, fireImmediately: true);
    addTearDown(subscription.close);

    await container.pump();
    await container.pump();
    final pending = subscription.read().requireValue;

    expect(pending, hasLength(1));
    expect(pending.single.id, 'pending-transaction');
    expect(pending.single.payload['amountKobo'], 125000);
  });

  test('offline sync retry provider replays queued transactions', () async {
    final queue = OfflineSyncQueue();
    final repository = FakeKoloRepository.seeded();
    await queue.enqueue(
      PendingSyncOperation(
        id: 'offline-transaction',
        kind: 'transaction',
        payload: {
          'id': 'tx-provider-retry',
          'amountKobo': 120000,
          'type': 'income',
          'category': 'Gig',
          'description': 'Offline gig payment',
          'date': DateTime(2026, 5, 24, 14).toIso8601String(),
          'source': 'manual',
        },
        createdAt: DateTime(2026, 5, 24, 14),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        offlineSyncQueueProvider.overrideWithValue(queue),
        koloRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final synced = await container.read(offlineSyncRetryProvider.future);
    final pending = await queue.watchPendingOperations().first;
    final dashboard = await repository.watchDashboard().first;

    expect(synced, 1);
    expect(pending, isEmpty);
    expect(
      dashboard.transactions
          .firstWhere((transaction) => transaction.id == 'tx-provider-retry')
          .type,
      TransactionType.income,
    );
  });
}
