import 'package:kolo/domain/models/models.dart';

class AiOverrideTone {
  const AiOverrideTone._();

  static const repeatedOverrideMessage =
      "I notice you've been overriding me a lot, want to adjust the budget instead?";

  static bool shouldAdjustTone(List<TransactionRecord> transactions) {
    final recentExpenses =
        transactions
            .where((transaction) => transaction.type == TransactionType.expense)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    if (recentExpenses.length < 2) return false;
    return recentExpenses
        .take(2)
        .every((transaction) => transaction.aiApproved == false);
  }
}
