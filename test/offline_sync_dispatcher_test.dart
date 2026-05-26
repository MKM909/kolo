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

  test(
    'retryPending upserts queued bill reminders and marks them synced',
    () async {
      final repository = FakeKoloRepository.seeded();
      final queue = OfflineSyncQueue();
      await queue.enqueue(
        PendingSyncOperation(
          id: 'offline-bill',
          kind: 'bill',
          payload: {
            'id': 'bill-offline-data',
            'name': 'Data renewal',
            'amountKobo': 150000,
            'frequency': 'monthly',
            'nextDue': DateTime(2026, 5, 27).toIso8601String(),
            'active': true,
          },
          createdAt: DateTime(2026, 5, 24),
        ),
      );

      final synced = await OfflineSyncDispatcher(
        queue: queue,
        repository: repository,
      ).retryPending();
      final pending = await queue.watchPendingOperations().first;
      final dashboard = await repository.watchDashboard().first;
      final bill = dashboard.bills.firstWhere(
        (bill) => bill.id == 'bill-offline-data',
      );

      expect(synced, 1);
      expect(pending, isEmpty);
      expect(bill.name, 'Data renewal');
      expect(bill.amountKobo, 150000);
      expect(bill.frequency, 'monthly');
      expect(bill.active, isTrue);
    },
  );

  test(
    'retryPending deletes queued bill reminders and marks them synced',
    () async {
      final repository = FakeKoloRepository.seeded();
      final queue = OfflineSyncQueue();
      await queue.enqueue(
        PendingSyncOperation(
          id: 'offline-delete-bill',
          kind: 'deleteBill',
          payload: const {'id': 'bill-data'},
          createdAt: DateTime(2026, 5, 24),
        ),
      );

      final synced = await OfflineSyncDispatcher(
        queue: queue,
        repository: repository,
      ).retryPending();
      final pending = await queue.watchPendingOperations().first;
      final dashboard = await repository.watchDashboard().first;

      expect(synced, 1);
      expect(pending, isEmpty);
      expect(dashboard.bills.where((bill) => bill.id == 'bill-data'), isEmpty);
    },
  );

  test('retryPending upserts queued gig income and marks it synced', () async {
    final repository = FakeKoloRepository.seeded();
    final queue = OfflineSyncQueue();
    await queue.enqueue(
      PendingSyncOperation(
        id: 'offline-gig',
        kind: 'gig',
        payload: {
          'id': 'gig-offline-brand',
          'client': 'Muna Foods',
          'amountKobo': 2500000,
          'date': DateTime(2026, 5, 22).toIso8601String(),
          'projectType': 'Brand kit',
          'note': 'Logged after offline meeting',
        },
        createdAt: DateTime(2026, 5, 24),
      ),
    );

    final synced = await OfflineSyncDispatcher(
      queue: queue,
      repository: repository,
    ).retryPending();
    final pending = await queue.watchPendingOperations().first;
    final dashboard = await repository.watchDashboard().first;
    final gig = dashboard.gigs.firstWhere(
      (gig) => gig.id == 'gig-offline-brand',
    );

    expect(synced, 1);
    expect(pending, isEmpty);
    expect(gig.client, 'Muna Foods');
    expect(gig.amountKobo, 2500000);
    expect(gig.projectType, 'Brand kit');
    expect(gig.note, 'Logged after offline meeting');
  });

  test('retryPending upserts queued owings and marks them synced', () async {
    final repository = FakeKoloRepository.seeded();
    final queue = OfflineSyncQueue();
    await queue.enqueue(
      PendingSyncOperation(
        id: 'offline-owing',
        kind: 'owing',
        payload: {
          'id': 'owing-offline-timi',
          'type': 'theyOweMe',
          'person': 'Timi',
          'amountKobo': 1200000,
          'date': DateTime(2026, 5, 18).toIso8601String(),
          'settled': false,
          'note': 'Lunch and transport',
          'dueDate': DateTime(2026, 5, 30).toIso8601String(),
        },
        createdAt: DateTime(2026, 5, 24),
      ),
    );

    final synced = await OfflineSyncDispatcher(
      queue: queue,
      repository: repository,
    ).retryPending();
    final pending = await queue.watchPendingOperations().first;
    final dashboard = await repository.watchDashboard().first;
    final owing = dashboard.owings.firstWhere(
      (owing) => owing.id == 'owing-offline-timi',
    );

    expect(synced, 1);
    expect(pending, isEmpty);
    expect(owing.type, OwingType.theyOweMe);
    expect(owing.person, 'Timi');
    expect(owing.amountKobo, 1200000);
    expect(owing.note, 'Lunch and transport');
    expect(owing.dueDate, DateTime(2026, 5, 30));
  });

  test('retryPending deletes queued owings and marks them synced', () async {
    final repository = FakeKoloRepository.seeded();
    final queue = OfflineSyncQueue();
    await queue.enqueue(
      PendingSyncOperation(
        id: 'offline-delete-owing',
        kind: 'deleteOwing',
        payload: const {'id': 'owing-timi'},
        createdAt: DateTime(2026, 5, 24),
      ),
    );

    final synced = await OfflineSyncDispatcher(
      queue: queue,
      repository: repository,
    ).retryPending();
    final pending = await queue.watchPendingOperations().first;
    final dashboard = await repository.watchDashboard().first;

    expect(synced, 1);
    expect(pending, isEmpty);
    expect(
      dashboard.owings.where((owing) => owing.id == 'owing-timi'),
      isEmpty,
    );
  });

  test('retryPending upserts queued vaults and marks them synced', () async {
    final repository = FakeKoloRepository.seeded();
    final queue = OfflineSyncQueue();
    await queue.enqueue(
      PendingSyncOperation(
        id: 'offline-vault',
        kind: 'vault',
        payload: {
          'id': 'vault-offline-rent',
          'name': 'Rent buffer',
          'targetKobo': 3000000,
          'currentKobo': 500000,
          'deadline': DateTime(2026, 8, 1).toIso8601String(),
        },
        createdAt: DateTime(2026, 5, 24),
      ),
    );

    final synced = await OfflineSyncDispatcher(
      queue: queue,
      repository: repository,
    ).retryPending();
    final pending = await queue.watchPendingOperations().first;
    final dashboard = await repository.watchDashboard().first;
    final vault = dashboard.vaults.firstWhere(
      (vault) => vault.id == 'vault-offline-rent',
    );

    expect(synced, 1);
    expect(pending, isEmpty);
    expect(vault.name, 'Rent buffer');
    expect(vault.targetKobo, 3000000);
    expect(vault.currentKobo, 500000);
    expect(vault.deadline, DateTime(2026, 8, 1));
  });

  test('retryPending deletes queued vaults and marks them synced', () async {
    final repository = FakeKoloRepository.seeded();
    final queue = OfflineSyncQueue();
    await queue.enqueue(
      PendingSyncOperation(
        id: 'offline-delete-vault',
        kind: 'deleteVault',
        payload: const {'id': 'vault-phone'},
        createdAt: DateTime(2026, 5, 24),
      ),
    );

    final synced = await OfflineSyncDispatcher(
      queue: queue,
      repository: repository,
    ).retryPending();
    final pending = await queue.watchPendingOperations().first;
    final dashboard = await repository.watchDashboard().first;

    expect(synced, 1);
    expect(pending, isEmpty);
    expect(
      dashboard.vaults.where((vault) => vault.id == 'vault-phone'),
      isEmpty,
    );
  });

  test(
    'retryPending upserts queued watched apps and marks them synced',
    () async {
      final repository = FakeKoloRepository.seeded();
      final queue = OfflineSyncQueue();
      await queue.enqueue(
        PendingSyncOperation(
          id: 'offline-watched-app',
          kind: 'watchedApp',
          payload: const {
            'packageName': 'com.kuda.app',
            'displayName': 'Kuda',
            'enabled': true,
          },
          createdAt: DateTime(2026, 5, 24),
        ),
      );

      final synced = await OfflineSyncDispatcher(
        queue: queue,
        repository: repository,
      ).retryPending();
      final pending = await queue.watchPendingOperations().first;
      final dashboard = await repository.watchDashboard().first;
      final app = dashboard.watchedApps.firstWhere(
        (app) => app.packageName == 'com.kuda.app',
      );

      expect(synced, 1);
      expect(pending, isEmpty);
      expect(app.displayName, 'Kuda');
      expect(app.enabled, isTrue);
    },
  );

  test('retryPending applies queued balance adjustments', () async {
    final repository = FakeKoloRepository.seeded();
    final queue = OfflineSyncQueue();
    await queue.enqueue(
      PendingSyncOperation(
        id: 'offline-balance',
        kind: 'balanceAdjustment',
        payload: {
          'id': 'balance-offline-1',
          'previousBalanceKobo': 5080000,
          'newBalanceKobo': 6100000,
          'note': 'Cash deposit caught up offline',
          'createdAt': DateTime(2026, 5, 24, 20).toIso8601String(),
        },
        createdAt: DateTime(2026, 5, 24, 20),
      ),
    );

    final synced = await OfflineSyncDispatcher(
      queue: queue,
      repository: repository,
    ).retryPending();
    final pending = await queue.watchPendingOperations().first;
    final dashboard = await repository.watchDashboard().first;

    expect(synced, 1);
    expect(pending, isEmpty);
    expect(dashboard.balanceKobo, 6100000);
    expect(dashboard.balanceAdjustments.first.id, 'balance-offline-1');
  });

  test('retryPending applies queued budget edits', () async {
    final repository = FakeKoloRepository.seeded();
    final queue = OfflineSyncQueue();
    await queue.enqueue(
      PendingSyncOperation(
        id: 'offline-budget',
        kind: 'budget',
        payload: const {
          'monthlyIncomeKobo': 9000000,
          'incomeType': 'salary',
          'savingsTargetKobo': 2500000,
          'savingsGoal': 'New laptop',
          'aiNotes': 'Protect savings first.',
          'categories': [
            {
              'name': 'Food',
              'emoji': 'food',
              'allocatedKobo': 1800000,
              'priority': 1,
            },
          ],
        },
        createdAt: DateTime(2026, 5, 24),
      ),
    );

    final synced = await OfflineSyncDispatcher(
      queue: queue,
      repository: repository,
    ).retryPending();
    final pending = await queue.watchPendingOperations().first;
    final dashboard = await repository.watchDashboard().first;

    expect(synced, 1);
    expect(pending, isEmpty);
    expect(dashboard.budgetPlan.monthlyIncomeKobo, 9000000);
    expect(dashboard.budgetPlan.categories.single.allocatedKobo, 1800000);
  });

  test('retryPending applies queued partner shares', () async {
    final repository = FakeKoloRepository.seeded();
    final queue = OfflineSyncQueue();
    await queue.enqueue(
      PendingSyncOperation(
        id: 'offline-partner',
        kind: 'partnerShare',
        payload: {
          'id': 'share-offline-1',
          'partnerEmail': 'friend@kolo.app',
          'status': 'pending',
          'permissions': const ['balance_summary', 'weekly_insights'],
          'createdAt': DateTime(2026, 5, 24).toIso8601String(),
        },
        createdAt: DateTime(2026, 5, 24),
      ),
    );

    final synced = await OfflineSyncDispatcher(
      queue: queue,
      repository: repository,
    ).retryPending();
    final pending = await queue.watchPendingOperations().first;
    final dashboard = await repository.watchDashboard().first;
    final share = dashboard.partnerShares.firstWhere(
      (share) => share.id == 'share-offline-1',
    );

    expect(synced, 1);
    expect(pending, isEmpty);
    expect(share.partnerEmail, 'friend@kolo.app');
    expect(share.permissions, {'balance_summary', 'weekly_insights'});
  });
}
