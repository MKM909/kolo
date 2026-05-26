import 'package:kolo/domain/models/models.dart';

abstract class SpendingJustificationAdvisor {
  Future<SpendingJustificationDecision> evaluateSpendingJustification({
    required DashboardState context,
    required TransactionRecord transaction,
    required String justification,
    String? modelName,
  });
}
