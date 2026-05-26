import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/repositories/queued_kolo_repository.dart';
import 'package:kolo/data/services/offline_sync_queue.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';

void main() {
  final fixedNow = DateTime(2026, 5, 26, 10, 15);

  test(
    'logTransaction queues the full transaction payload when remote write fails',
    () async {
      final queue = OfflineSyncQueue();
      final repository = QueuedKoloRepository(
        remote: _OfflineRepository(),
        queue: queue,
        now: () => fixedNow,
        idFactory: (kind) => 'pending-$kind',
      );

      await repository.logTransaction(
        TransactionRecord.expense(
          id: 'tx-queued-food',
          amountKobo: 450000,
          category: 'Food',
          description: 'Late lunch',
          date: DateTime(2026, 5, 26, 9, 30),
          source: TransactionSource.manual,
          merchantName: 'Chicken Republic',
          aiApproved: false,
          aiNote: 'User overrode Kolo caution.',
        ),
      );

      final pending = await queue.watchPendingOperations().first;

      expect(pending, hasLength(1));
      expect(pending.single.id, 'pending-transaction');
      expect(pending.single.kind, 'transaction');
      expect(pending.single.createdAt, fixedNow);
      expect(pending.single.payload, {
        'id': 'tx-queued-food',
        'amountKobo': 450000,
        'type': 'expense',
        'category': 'Food',
        'description': 'Late lunch',
        'date': DateTime(2026, 5, 26, 9, 30).toIso8601String(),
        'source': 'manual',
        'merchantName': 'Chicken Republic',
        'aiApproved': false,
        'aiNote': 'User overrode Kolo caution.',
      });
    },
  );

  test('successful remote writes are not queued', () async {
    final queue = OfflineSyncQueue();
    final remote = _SuccessfulRepository();
    final repository = QueuedKoloRepository(
      remote: remote,
      queue: queue,
      now: () => fixedNow,
      idFactory: (kind) => 'pending-$kind',
    );

    await repository.logTransaction(
      TransactionRecord.income(
        id: 'tx-online-gig',
        amountKobo: 2500000,
        category: 'Gig Income',
        description: 'Brand work',
        date: fixedNow,
        source: TransactionSource.manual,
        merchantName: 'Muna Foods',
      ),
    );

    final pending = await queue.watchPendingOperations().first;

    expect(remote.loggedTransactions, ['tx-online-gig']);
    expect(pending, isEmpty);
  });

  test(
    'queues every offline-safe dashboard write when the remote write fails',
    () async {
      final queue = OfflineSyncQueue();
      final repository = QueuedKoloRepository(
        remote: _OfflineRepository(),
        queue: queue,
        now: () => fixedNow,
        idFactory: (kind) => 'pending-$kind',
      );

      await repository.adjustBalance(
        BalanceAdjustment(
          id: 'balance-1',
          previousBalanceKobo: 1000000,
          newBalanceKobo: 1250000,
          note: 'Cash deposit',
          createdAt: fixedNow,
        ),
      );
      await repository.updateBudget(
        const BudgetPlan(
          monthlyIncomeKobo: 9000000,
          incomeType: 'salary',
          categories: [
            BudgetCategory(
              name: 'Food',
              emoji: 'food',
              allocatedKobo: 1500000,
              priority: 1,
            ),
          ],
          savingsTargetKobo: 2500000,
          savingsGoal: 'Laptop',
          aiNotes: 'Protect savings.',
        ),
      );
      await repository.upsertBill(
        BillReminder(
          id: 'bill-data',
          name: 'Data',
          amountKobo: 1000000,
          frequency: 'monthly',
          nextDue: DateTime(2026, 5, 29),
        ),
      );
      await repository.deleteBill('bill-data');
      await repository.upsertGig(
        GigRecord(
          id: 'gig-1',
          client: 'Muna Foods',
          amountKobo: 2500000,
          date: fixedNow,
          projectType: 'Brand kit',
          note: 'Offline meeting',
        ),
      );
      await repository.upsertOwing(
        Owing(
          id: 'owing-1',
          type: OwingType.theyOweMe,
          person: 'Timi',
          amountKobo: 700000,
          date: fixedNow,
          note: 'Lunch',
          dueDate: DateTime(2026, 6, 1),
        ),
      );
      await repository.deleteOwing('owing-1');
      await repository.upsertVault(
        SavingsVault(
          id: 'vault-rent',
          name: 'Rent',
          targetKobo: 8000000,
          currentKobo: 2400000,
          deadline: DateTime(2026, 8, 1),
        ),
      );
      await repository.deleteVault('vault-rent');
      await repository.upsertWatchedApp(
        const WatchedApp(
          packageName: 'team.opay.pay',
          displayName: 'Opay',
          enabled: true,
        ),
      );
      await repository.upsertPartnerShare(
        PartnerShare(
          id: 'share-1',
          partnerEmail: 'friend@kolo.app',
          status: ShareStatus.pending,
          permissions: const {'balance_summary'},
          createdAt: fixedNow,
        ),
      );

      final pending = await queue.watchPendingOperations().first;

      expect(pending.map((operation) => operation.kind), [
        'balanceAdjustment',
        'budget',
        'bill',
        'deleteBill',
        'gig',
        'owing',
        'deleteOwing',
        'vault',
        'deleteVault',
        'watchedApp',
        'partnerShare',
      ]);
      expect(
        pending.every((operation) => operation.createdAt == fixedNow),
        true,
      );
      expect(pending[0].payload['newBalanceKobo'], 1250000);
      expect(pending[1].payload['categories'], [
        {
          'name': 'Food',
          'emoji': 'food',
          'allocatedKobo': 1500000,
          'priority': 1,
        },
      ]);
      expect(pending[3].payload, {'id': 'bill-data'});
      expect(
        pending[5].payload['dueDate'],
        DateTime(2026, 6, 1).toIso8601String(),
      );
      expect(
        pending[7].payload['deadline'],
        DateTime(2026, 8, 1).toIso8601String(),
      );
      expect(pending[10].payload['permissions'], ['balance_summary']);
    },
  );

  test(
    'app wires queued Firebase writes without using the queue for retry replay',
    () {
      final providers = File('lib/app/providers.dart').readAsStringSync();

      expect(providers, contains('QueuedKoloRepository'));
      expect(providers, contains('firebaseKoloRemoteRepositoryProvider'));
      expect(providers, contains('offlineSyncTargetRepositoryProvider'));
    },
  );
}

class _OfflineRepository implements KoloRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw StateError('offline');
  }
}

class _SuccessfulRepository implements KoloRepository {
  final List<String> loggedTransactions = [];

  @override
  Future<void> logTransaction(TransactionRecord transaction) async {
    loggedTransactions.add(transaction.id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
