import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/data/services/offline_sync_queue.dart';

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
}
