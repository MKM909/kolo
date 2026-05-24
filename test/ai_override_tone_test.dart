import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/ai_override_tone.dart';

void main() {
  test('does not adjust tone before repeated AI overrides', () {
    final transactions = [
      _expense(id: 'tx-1', aiApproved: false),
      _expense(id: 'tx-2', aiApproved: true),
    ];

    expect(AiOverrideTone.shouldAdjustTone(transactions), isFalse);
  });

  test('adjusts tone after two recent AI-cautioned expenses', () {
    final transactions = [
      _expense(id: 'tx-1', aiApproved: false),
      _expense(id: 'tx-2', aiApproved: false),
      _expense(id: 'tx-3', aiApproved: true),
    ];

    expect(AiOverrideTone.shouldAdjustTone(transactions), isTrue);
    expect(
      AiOverrideTone.repeatedOverrideMessage,
      "I notice you've been overriding me a lot, want to adjust the budget instead?",
    );
  });
}

TransactionRecord _expense({required String id, required bool aiApproved}) {
  return TransactionRecord.expense(
    id: id,
    amountKobo: 100000,
    category: 'Food & Snacks',
    description: id,
    date: DateTime(2026, 5, 24),
    source: TransactionSource.manual,
    aiApproved: aiApproved,
  );
}
