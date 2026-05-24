import 'package:kolo/domain/models/models.dart';

abstract class KoloRepository {
  Stream<DashboardState> watchDashboard();
  Future<void> adjustBalance(BalanceAdjustment adjustment);
  Future<void> upsertVault(SavingsVault vault);
  Future<void> logTransaction(TransactionRecord transaction);
  Future<BudgetPlan> completeOnboarding(OnboardingAnswers answers);
  Future<BudgetPlan> generateBudget(OnboardingAnswers answers);
  Future<AiMessage> sendAiMessage(String message);
  Future<void> updateBudget(BudgetPlan budget);
  Future<void> updatePermission(
    KoloPermission permission,
    PermissionGrantState state,
  );
}
