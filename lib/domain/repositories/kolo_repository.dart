import 'package:kolo/domain/models/models.dart';

abstract class KoloRepository {
  Stream<DashboardState> watchDashboard();
  Future<void> adjustBalance(BalanceAdjustment adjustment);
  Future<void> upsertVault(SavingsVault vault);
  Future<void> upsertOwing(Owing owing);
  Future<void> upsertGig(GigRecord gig);
  Future<void> upsertBill(BillReminder bill);
  Future<void> upsertPartnerShare(PartnerShare share);
  Future<void> upsertWatchedApp(WatchedApp app);
  Future<void> logTransaction(TransactionRecord transaction);
  Future<void> recordAiMessage(AiMessage message);
  Future<String> draftOwingReminder(Owing owing);
  Future<WeeklyInsight> generateWeeklyInsight();
  Future<BudgetPlan> completeOnboarding(OnboardingAnswers answers);
  Future<BudgetPlan> generateBudget(OnboardingAnswers answers);
  Future<AiMessage> sendAiMessage(String message);
  Future<void> updateBudget(BudgetPlan budget);
  Future<void> updatePermission(
    KoloPermission permission,
    PermissionGrantState state,
  );
}
