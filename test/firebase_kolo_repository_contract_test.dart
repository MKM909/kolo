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
}
