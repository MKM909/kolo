import 'package:kolo/domain/models/models.dart';

abstract class TransactionCategorizer {
  Future<TransactionDraft?> categorizeTransaction({
    required String rawText,
    required TransactionSource source,
    required DashboardState context,
  });
}
