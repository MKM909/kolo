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
        },
      ],
      owings: const [],
      gigs: const [],
      bills: const [],
      watchedApps: const [],
      partnerShares: const [],
      insights: const [],
      now: DateTime(2026, 5, 24),
    );

    expect(state.profile.uid, 'user-123');
    expect(state.profile.name, 'Micah');
    expect(state.profile.createdAt, createdAt);
    expect(state.balanceKobo, 1234500);
    expect(state.balanceAdjustments.single.deltaKobo, 234500);
    expect(state.budgetPlan.savingsGoal, 'Laptop');
    expect(state.budgetPlan.categories.single.name, 'Food & Snacks');
    expect(state.transactions.single.type, TransactionType.expense);
    expect(state.transactions.single.source, TransactionSource.sms);
    expect(state.transactions.single.aiApproved, isFalse);
    expect(state.aiMessages.single.role, AiRole.assistant);
    expect(state.vaults.single.progress, closeTo(0.023, 0.001));
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
      ),
    );

    expect(payload['name'], 'Detty December');
    expect(payload['targetKobo'], 25000000);
    expect(payload['currentKobo'], 750000);
    expect((payload['deadline'] as Timestamp).toDate(), deadline);
  });
}
