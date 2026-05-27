import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/sms_received_handler.dart';
import 'package:kolo/domain/services/spending_intervention_advisor.dart';
import 'package:kolo/domain/services/spending_justification_advisor.dart';
import 'package:kolo/domain/services/transaction_categorizer.dart';

abstract class KoloAiService
    implements
        TransactionCategorizer,
        SpendingInterventionAdvisor,
        SpendingJustificationAdvisor,
        SmsReceivedHandler {
  Future<String> chatWithKolo({
    required String message,
    required DashboardState context,
    String? modelName,
  });

  Future<BudgetPlan> generateBudget(
    OnboardingAnswers answers, {
    String? modelName,
  });

  Future<String> draftReminder({
    required Owing owing,
    required DashboardState context,
    String? modelName,
  });

  Future<WeeklyInsight> analyzeSpending({
    required DashboardState context,
    String? modelName,
  });
}
