import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kolo/data/repositories/cached_kolo_repository.dart';
import 'package:kolo/data/services/hive_dashboard_cache_store.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';

void main() {
  test(
    'HiveDashboardCacheStore saves and restores full dashboard state',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kolo_cache_test',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<Object?>('dashboard_cache_test');
      addTearDown(() async {
        await box.close();
        await directory.delete(recursive: true);
      });

      final store = HiveDashboardCacheStore(box);
      final dashboard = _dashboardState();

      await store.save(
        uid: 'user-1',
        dashboard: dashboard,
        metadata: CachedDashboardMetadata(
          uid: 'user-1',
          cachedAt: DateTime(2026, 5, 26, 10),
        ),
      );

      final cached = await store.load('user-1');

      expect(cached, isNotNull);
      expect(cached!.metadata.uid, 'user-1');
      expect(cached.metadata.cachedAt, DateTime(2026, 5, 26, 10));
      expect(cached.dashboard.profile.name, 'Micah');
      expect(cached.dashboard.balanceKobo, 1250000);
      expect(cached.dashboard.transactions.single.aiNote, 'Allowed for lunch');
      expect(
        cached.dashboard.vaults.single.contributions.single.amountKobo,
        500000,
      );
      expect(
        cached.dashboard.vaults.single.contributions.single.createdAt,
        DateTime(2026, 5, 6, 14),
      );
      expect(cached.dashboard.bills.single.name, 'Data');
      expect(cached.dashboard.watchedApps.single.packageName, 'team.opay.pay');
      expect(
        cached.dashboard.watchedApps.single.blockLevel,
        WatchedAppBlockLevel.explain,
      );
      expect(cached.dashboard.partnerShares.single.permissions, {'balance'});
      expect(
        cached.dashboard.permissions[KoloPermission.notifications],
        PermissionGrantState.granted,
      );
    },
  );

  test(
    'CachedKoloRepository emits cached dashboard when remote stream errors',
    () async {
      final cache = MemoryDashboardCacheStore();
      await cache.save(
        uid: 'user-1',
        dashboard: _dashboardState(balanceKobo: 990000),
        metadata: CachedDashboardMetadata(
          uid: 'user-1',
          cachedAt: DateTime(2026, 5, 26),
        ),
      );

      final repository = CachedKoloRepository(
        uid: 'user-1',
        remote: _RemoteDashboardRepository(Stream.error(StateError('offline'))),
        cache: cache,
      );

      final dashboard = await repository.watchDashboard().first;

      expect(dashboard.balanceKobo, 990000);
    },
  );

  test('CachedKoloRepository saves live dashboard snapshots', () async {
    final cache = MemoryDashboardCacheStore();
    final repository = CachedKoloRepository(
      uid: 'user-1',
      remote: _RemoteDashboardRepository(Stream.value(_dashboardState())),
      cache: cache,
    );

    final live = await repository.watchDashboard().first;
    final cached = await cache.load('user-1');

    expect(live.balanceKobo, 1250000);
    expect(cached!.dashboard.balanceKobo, 1250000);
    expect(cached.metadata.source, 'firestore');
  });

  test('app wires dashboard cache into Firebase repository selection', () {
    final providers = File('lib/app/providers.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(providers, contains('dashboardCacheStoreProvider'));
    expect(providers, contains('CachedKoloRepository'));
    expect(providers, contains('HiveDashboardCacheStore'));
    expect(main, contains('Hive.initFlutter'));
    expect(main, contains('koloDashboardCacheBoxName'));
  });
}

DashboardState _dashboardState({int balanceKobo = 1250000}) {
  return DashboardState(
    profile: UserProfile(
      uid: 'user-1',
      name: 'Micah',
      email: 'micah@kolo.app',
      createdAt: DateTime(2026, 5, 1),
      onboardingComplete: true,
    ),
    balanceKobo: balanceKobo,
    balanceAdjustments: [
      BalanceAdjustment(
        id: 'adjustment-1',
        previousBalanceKobo: 1000000,
        newBalanceKobo: balanceKobo,
        note: 'Corrected',
        createdAt: DateTime(2026, 5, 2),
      ),
    ],
    budgetPlan: const BudgetPlan(
      monthlyIncomeKobo: 5000000,
      incomeType: 'salary',
      categories: [
        BudgetCategory(
          name: 'Food',
          emoji: 'food',
          allocatedKobo: 1500000,
          priority: 1,
        ),
      ],
      savingsTargetKobo: 1000000,
      savingsGoal: 'Phone',
      aiNotes: 'Keep food tight.',
    ),
    transactions: [
      TransactionRecord.expense(
        id: 'txn-1',
        amountKobo: 250000,
        category: 'Food',
        description: 'Lunch',
        date: DateTime(2026, 5, 3),
        source: TransactionSource.manual,
        merchantName: 'Chicken Republic',
        aiApproved: true,
        aiNote: 'Allowed for lunch',
      ),
    ],
    aiMessages: [
      AiMessage(
        id: 'ai-1',
        role: AiRole.assistant,
        content: 'Stay under budget.',
        timestamp: DateTime(2026, 5, 4),
        context: 'chat',
      ),
    ],
    vaults: [
      SavingsVault(
        id: 'vault-1',
        name: 'Phone',
        targetKobo: 10000000,
        currentKobo: 2500000,
        contributions: [
          VaultContribution(
            id: 'contribution-1',
            amountKobo: 500000,
            createdAt: DateTime(2026, 5, 6, 14),
            note: 'Weekly save',
          ),
        ],
      ),
    ],
    owings: [
      Owing(
        id: 'owing-1',
        type: OwingType.theyOweMe,
        person: 'Tola',
        amountKobo: 300000,
        date: DateTime(2026, 5, 5),
        dueDate: DateTime(2026, 5, 9),
      ),
    ],
    gigs: [
      GigRecord(
        id: 'gig-1',
        client: 'Studio',
        amountKobo: 2000000,
        date: DateTime(2026, 5, 6),
        projectType: 'Design',
      ),
    ],
    bills: [
      BillReminder(
        id: 'bill-1',
        name: 'Data',
        amountKobo: 500000,
        frequency: 'Monthly',
        nextDue: DateTime(2026, 5, 10),
      ),
    ],
    watchedApps: const [
      WatchedApp(
        packageName: 'team.opay.pay',
        displayName: 'Opay',
        blockLevel: WatchedAppBlockLevel.explain,
      ),
    ],
    partnerShares: [
      PartnerShare(
        id: 'share-1',
        partnerEmail: 'friend@kolo.app',
        status: ShareStatus.active,
        permissions: const {'balance'},
        createdAt: DateTime(2026, 5, 7),
      ),
    ],
    insights: [
      WeeklyInsight(
        id: 'insight-1',
        title: 'Food spike',
        body: 'Lunch is rising.',
        createdAt: DateTime(2026, 5, 8),
      ),
    ],
    permissions: const {
      KoloPermission.sms: PermissionGrantState.notRequested,
      KoloPermission.notifications: PermissionGrantState.granted,
      KoloPermission.overlay: PermissionGrantState.notRequested,
      KoloPermission.accessibility: PermissionGrantState.denied,
      KoloPermission.backgroundService: PermissionGrantState.notRequested,
    },
  );
}

class _RemoteDashboardRepository implements KoloRepository {
  const _RemoteDashboardRepository(this.stream);

  final Stream<DashboardState> stream;

  @override
  Stream<DashboardState> watchDashboard() => stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
