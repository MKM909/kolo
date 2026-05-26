import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/repositories/firebase_kolo_mapper.dart';
import 'package:kolo/domain/models/models.dart';

void main() {
  test('maps Firestore dashboard payload into Kolo domain state', () {
    final createdAt = DateTime(2026, 5, 1);
    final txDate = DateTime(2026, 5, 24, 11, 30);

    final state = FirebaseKoloMapper.dashboardFromPayload(
      uid: 'user-123',
      user: {
        'name': 'Micah',
        'email': 'micah@example.com',
        'createdAt': Timestamp.fromDate(createdAt),
        'onboardingComplete': true,
        'preferredAiModel': 'gemini-3.1-flash',
        'notificationPreferences': {
          'transactionAlerts': true,
          'budgetWarnings': false,
          'billReminders': true,
          'weeklyInsights': false,
          'bubbleInterventions': true,
        },
        'balanceKobo': 1234500,
        'budgetPlan': {
          'monthlyIncomeKobo': 5000000,
          'incomeType': 'irregular',
          'savingsTargetKobo': 700000,
          'savingsGoal': 'Laptop',
          'aiNotes': 'Protect savings first.',
          'categories': [
            {
              'name': 'Food & Snacks',
              'emoji': 'food',
              'allocatedKobo': 1500000,
              'priority': 1,
            },
          ],
        },
        'permissions': {'sms': 'granted', 'overlay': 'denied'},
      },
      balanceAdjustments: [
        {
          'id': 'adjust-1',
          'previousBalanceKobo': 1000000,
          'newBalanceKobo': 1234500,
          'note': 'Corrected from bank app',
          'createdAt': Timestamp.fromDate(txDate),
        },
      ],
      transactions: [
        {
          'id': 'tx-food',
          'amountKobo': 250000,
          'type': 'expense',
          'category': 'Food & Snacks',
          'description': 'Lunch',
          'date': Timestamp.fromDate(txDate),
          'source': 'sms',
          'merchantName': 'Bukka',
          'aiApproved': false,
          'aiNote': 'Food budget is warm.',
        },
      ],
      aiMessages: [
        {
          'id': 'ai-1',
          'role': 'assistant',
          'content': 'Spend gently today.',
          'timestamp': Timestamp.fromDate(txDate),
          'context': 'home',
        },
      ],
      vaults: [
        {
          'id': 'vault-1',
          'name': 'Laptop',
          'targetKobo': 30000000,
          'currentKobo': 700000,
          'contributions': [
            {
              'id': 'contribution-1',
              'amountKobo': 250000,
              'createdAt': Timestamp.fromDate(DateTime(2026, 5, 20, 9)),
              'note': 'May transfer',
            },
          ],
        },
      ],
      owings: const [],
      gigs: const [],
      bills: const [],
      watchedApps: const [
        {
          'packageName': 'com.kuda.app',
          'displayName': 'Kuda',
          'enabled': true,
          'blockLevel': 'hardLock',
        },
      ],
      partnerShares: const [],
      insights: const [],
      now: DateTime(2026, 5, 24),
    );

    expect(state.profile.uid, 'user-123');
    expect(state.profile.name, 'Micah');
    expect(state.profile.createdAt, createdAt);
    expect(state.profile.preferredAiModel, 'gemini-3.1-flash');
    expect(state.profile.notificationPreferences.budgetWarnings, isFalse);
    expect(state.profile.notificationPreferences.weeklyInsights, isFalse);
    expect(state.profile.notificationPreferences.bubbleInterventions, isTrue);
    expect(state.balanceKobo, 1234500);
    expect(state.balanceAdjustments.single.deltaKobo, 234500);
    expect(state.budgetPlan.savingsGoal, 'Laptop');
    expect(state.budgetPlan.categories.single.name, 'Food & Snacks');
    expect(state.transactions.single.type, TransactionType.expense);
    expect(state.transactions.single.source, TransactionSource.sms);
    expect(state.transactions.single.aiApproved, isFalse);
    expect(state.aiMessages.single.role, AiRole.assistant);
    expect(state.vaults.single.progress, closeTo(0.023, 0.001));
    expect(state.vaults.single.contributions.single.amountKobo, 250000);
    expect(
      state.vaults.single.contributions.single.createdAt,
      DateTime(2026, 5, 20, 9),
    );
    expect(state.watchedApps.single.blockLevel, WatchedAppBlockLevel.hardLock);
    expect(state.permissions[KoloPermission.sms], PermissionGrantState.granted);
    expect(
      state.permissions[KoloPermission.overlay],
      PermissionGrantState.denied,
    );
    expect(
      state.permissions[KoloPermission.notifications],
      PermissionGrantState.notRequested,
    );
  });

  test('supplies launch-safe defaults for an empty Firebase profile', () {
    final state = FirebaseKoloMapper.dashboardFromPayload(
      uid: 'new-user',
      user: const {},
      balanceAdjustments: const [],
      transactions: const [],
      aiMessages: const [],
      vaults: const [],
      owings: const [],
      gigs: const [],
      bills: const [],
      watchedApps: const [],
      partnerShares: const [],
      insights: const [],
      now: DateTime(2026, 5, 24),
    );

    expect(state.profile.uid, 'new-user');
    expect(state.profile.name, 'Kolo User');
    expect(state.profile.onboardingComplete, isFalse);
    expect(state.profile.preferredAiModel, 'gemini-3.1-flash-lite');
    expect(state.profile.notificationPreferences.transactionAlerts, isTrue);
    expect(state.profile.notificationPreferences.budgetWarnings, isTrue);
    expect(state.profile.notificationPreferences.billReminders, isTrue);
    expect(state.profile.notificationPreferences.weeklyInsights, isTrue);
    expect(state.profile.notificationPreferences.bubbleInterventions, isTrue);
    expect(state.balanceKobo, 0);
    expect(state.budgetPlan.categories, isNotEmpty);
    expect(state.permissions.length, KoloPermission.values.length);
  });

  test('serializes savings vaults for Firebase persistence', () {
    final deadline = DateTime(2026, 12, 1);

    final payload = FirebaseKoloMapper.vaultToJson(
      SavingsVault(
        id: 'vault-trip',
        name: 'Detty December',
        targetKobo: 25000000,
        currentKobo: 750000,
        deadline: deadline,
        contributions: [
          VaultContribution(
            id: 'contribution-trip-1',
            amountKobo: 750000,
            createdAt: DateTime(2026, 5, 26, 8, 30),
            note: 'First stash',
          ),
        ],
      ),
    );

    expect(payload['name'], 'Detty December');
    expect(payload['targetKobo'], 25000000);
    expect(payload['currentKobo'], 750000);
    expect((payload['deadline'] as Timestamp).toDate(), deadline);
    final contributions =
        payload['contributions']! as List<Map<String, Object?>>;
    expect(contributions.single['id'], 'contribution-trip-1');
    expect(contributions.single['amountKobo'], 750000);
    expect(
      (contributions.single['createdAt']! as Timestamp).toDate(),
      DateTime(2026, 5, 26, 8, 30),
    );
    expect(contributions.single['note'], 'First stash');
  });

  test('serializes owings for Firebase persistence', () {
    final date = DateTime(2026, 5, 24);

    final payload = FirebaseKoloMapper.owingToJson(
      Owing(
        id: 'owing-sade',
        type: OwingType.theyOweMe,
        person: 'Sade',
        amountKobo: 1200000,
        date: date,
        settled: true,
        note: 'Design deposit',
      ),
    );

    expect(payload['type'], 'theyOweMe');
    expect(payload['person'], 'Sade');
    expect(payload['amountKobo'], 1200000);
    expect(payload['settled'], isTrue);
    expect((payload['date'] as Timestamp).toDate(), date);
  });

  test('serializes gig records for Firebase persistence', () {
    final date = DateTime(2026, 5, 24);

    final payload = FirebaseKoloMapper.gigToJson(
      GigRecord(
        id: 'gig-brand',
        client: 'Muna Foods',
        amountKobo: 9000000,
        date: date,
        projectType: 'Brand kit',
        note: 'Added social templates',
      ),
    );

    expect(payload['client'], 'Muna Foods');
    expect(payload['amountKobo'], 9000000);
    expect(payload['projectType'], 'Brand kit');
    expect(payload['note'], 'Added social templates');
    expect((payload['date'] as Timestamp).toDate(), date);
  });

  test('serializes bill reminders for Firebase persistence', () {
    final dueDate = DateTime(2026, 6, 1);

    final payload = FirebaseKoloMapper.billToJson(
      BillReminder(
        id: 'bill-wifi',
        name: 'Wifi subscription',
        amountKobo: 1800000,
        frequency: 'Monthly',
        nextDue: dueDate,
        active: false,
      ),
    );

    expect(payload['name'], 'Wifi subscription');
    expect(payload['amountKobo'], 1800000);
    expect(payload['frequency'], 'Monthly');
    expect(payload['active'], isFalse);
    expect((payload['nextDue'] as Timestamp).toDate(), dueDate);
  });

  test('serializes partner shares for Firebase persistence', () {
    final createdAt = DateTime(2026, 5, 24);
    final revokedAt = DateTime(2026, 5, 25);

    final payload = FirebaseKoloMapper.partnerShareToJson(
      PartnerShare(
        id: 'share-ade',
        partnerEmail: 'ade@example.com',
        status: ShareStatus.revoked,
        permissions: const {'balance_summary', 'budget_summary'},
        createdAt: createdAt,
        revokedAt: revokedAt,
      ),
    );

    expect(payload['partnerEmail'], 'ade@example.com');
    expect(payload['status'], 'revoked');
    expect(payload['permissions'], contains('budget_summary'));
    expect((payload['createdAt'] as Timestamp).toDate(), createdAt);
    expect((payload['revokedAt'] as Timestamp).toDate(), revokedAt);
  });

  test('serializes watched apps for Firebase persistence', () {
    final payload = FirebaseKoloMapper.watchedAppToJson(
      const WatchedApp(
        packageName: 'com.moniebank.personal',
        displayName: 'Moniepoint',
        enabled: true,
        blockLevel: WatchedAppBlockLevel.explain,
      ),
    );

    expect(payload['packageName'], 'com.moniebank.personal');
    expect(payload['displayName'], 'Moniepoint');
    expect(payload['enabled'], isTrue);
    expect(payload['blockLevel'], 'explain');
  });

  test('serializes weekly insights for Firebase persistence', () {
    final createdAt = DateTime(2026, 5, 24, 18);

    final payload = FirebaseKoloMapper.insightToJson(
      WeeklyInsight(
        id: 'insight-food',
        title: 'Food spending is heating up',
        body: 'Kolo noticed more late-night food this week.',
        createdAt: createdAt,
      ),
    );

    expect(payload['title'], 'Food spending is heating up');
    expect(payload['body'], contains('Kolo noticed'));
    expect((payload['createdAt'] as Timestamp).toDate(), createdAt);
  });
}
