import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firebase transaction logging is idempotent by transaction id', () {
    final source = File(
      'lib/data/repositories/firebase_kolo_repository.dart',
    ).readAsStringSync();

    expect(source, contains('final transactionDoc = _userDoc'));
    expect(source, contains(".collection('transactions')"));
    expect(source, contains('.doc(transaction.id)'));
    expect(
      source,
      contains('final existingTransaction = await dbTransaction.get'),
    );
    expect(source, contains('if (existingTransaction.exists) return;'));
    expect(source, contains('dbTransaction.set(transactionDoc'));
  });

  test('Firebase onboarding stores AI context message', () {
    final source = File(
      'lib/data/repositories/firebase_kolo_repository.dart',
    ).readAsStringSync();

    expect(source, contains("context: 'onboarding'"));
    expect(source, contains(".collection('aiMessages')"));
    expect(source, contains('FirebaseKoloMapper.aiMessageToJson'));
    expect(source, contains('Your first Kolo budget is ready'));
  });

  test(
    'Firebase onboarding can persist an already generated preview budget',
    () {
      final source = File(
        'lib/data/repositories/firebase_kolo_repository.dart',
      ).readAsStringSync();

      expect(source, contains('Future<BudgetPlan> completeOnboarding('));
      expect(source, contains('BudgetPlan? budget'));
      expect(source, contains('budget ??'));
      expect(source, contains('_aiService.generateBudget'));
    },
  );

  test('Firebase budget generation does not persist preview budgets', () {
    final source = File(
      'lib/data/repositories/firebase_kolo_repository.dart',
    ).readAsStringSync();
    final body = RegExp(
      r'Future<BudgetPlan> generateBudget\(OnboardingAnswers answers\) async \{([\s\S]*?)\n  \}',
    ).firstMatch(source)!.group(1)!;

    expect(body, contains('_aiService.generateBudget'));
    expect(body, isNot(contains('updateBudget')));
    expect(body, isNot(contains("'budgetPlan'")));
  });

  test('Firebase profile persists notification preferences as one map', () {
    final source = File(
      'lib/data/repositories/firebase_kolo_repository.dart',
    ).readAsStringSync();

    expect(source, contains('Future<void> updateNotificationPreferences('));
    expect(source, contains("'notificationPreferences'"));
    expect(source, contains('preferences.toJson()'));
    expect(source, contains('SetOptions(merge: true)'));
  });
}
