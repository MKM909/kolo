import 'package:cloud_functions/cloud_functions.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/ai_context_builder.dart';
import 'package:kolo/domain/services/ai_failure_message.dart';
import 'package:kolo/domain/services/spending_intervention_advisor.dart';
import 'package:kolo/domain/services/transaction_categorizer.dart';

class CloudAiService
    implements TransactionCategorizer, SpendingInterventionAdvisor {
  CloudAiService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<String> chatWithKolo({
    required String message,
    required DashboardState context,
  }) async {
    try {
      final callable = _functions.httpsCallable('chatWithKolo');
      final response = await callable.call<Map<String, dynamic>>({
        'message': message,
        'context': _contextPayload(context),
      });
      return response.data['content'] as String? ?? AiFailureMessage.chat;
    } on Object catch (_) {
      return AiFailureMessage.chat;
    }
  }

  Future<BudgetPlan> generateBudget(OnboardingAnswers answers) async {
    try {
      final callable = _functions.httpsCallable('generateBudget');
      final response = await callable.call<Map<String, dynamic>>({
        'answers': {
          'incomeSource': answers.incomeSource,
          'incomeFrequency': answers.incomeFrequency,
          'currentBalanceKobo': answers.currentBalanceKobo,
          'biggestProblem': answers.biggestProblem,
          'savingsGoal': answers.savingsGoal,
        },
      });
      return _budgetFromPayload(response.data);
    } on Object catch (_) {
      return _fallbackBudget(answers);
    }
  }

  @override
  Future<String> interventionMessage({required DashboardState context}) async {
    try {
      final callable = _functions.httpsCallable('interventionMessage');
      final response = await callable.call<Map<String, dynamic>>({
        'context': _contextPayload(context),
      });
      return response.data['content'] as String? ??
          AiFailureMessage.intervention;
    } on Object catch (_) {
      return AiFailureMessage.intervention;
    }
  }

  @override
  Future<TransactionDraft?> categorizeTransaction({
    required String rawText,
    required TransactionSource source,
    required DashboardState context,
  }) async {
    try {
      final callable = _functions.httpsCallable('categorizeTransaction');
      final response = await callable.call<Map<String, dynamic>>({
        'rawText': rawText,
        'source': source.name,
        'context': _contextPayload(context),
      });
      return _transactionDraftFromPayload(
        rawText: rawText,
        source: source,
        payload: response.data,
      );
    } on Object catch (_) {
      return null;
    }
  }

  Future<String> draftReminder({
    required Owing owing,
    required DashboardState context,
  }) async {
    try {
      final callable = _functions.httpsCallable('draftReminder');
      final response = await callable.call<Map<String, dynamic>>({
        'owing': {
          'person': owing.person,
          'amountKobo': owing.amountKobo,
          'note': owing.note,
        },
        'context': _contextPayload(context),
      });
      return response.data['message'] as String? ?? _fallbackReminder(owing);
    } on Object catch (_) {
      return _fallbackReminder(owing);
    }
  }

  Future<WeeklyInsight> analyzeSpending({
    required DashboardState context,
  }) async {
    try {
      final callable = _functions.httpsCallable('analyzeSpending');
      final response = await callable.call<Map<String, dynamic>>({
        'context': _contextPayload(context),
      });
      return _weeklyInsightFromPayload(response.data);
    } on Object catch (_) {
      return _fallbackInsight();
    }
  }

  Map<String, Object?> _contextPayload(DashboardState state) {
    return AiContextBuilder.build(state);
  }

  BudgetPlan _budgetFromPayload(Map<String, dynamic> payload) {
    final categories = (payload['categories'] as List<dynamic>? ?? [])
        .whereType<Map<Object?, Object?>>()
        .map(
          (item) => BudgetCategory(
            name: item['name'] as String? ?? 'Miscellaneous',
            emoji: item['emoji'] as String? ?? '•',
            allocatedKobo: item['allocatedKobo'] as int? ?? 0,
            priority: item['priority'] as int? ?? 9,
          ),
        )
        .toList();

    return BudgetPlan(
      monthlyIncomeKobo: payload['monthlyIncomeKobo'] as int? ?? 0,
      incomeType: payload['incomeType'] as String? ?? 'irregular',
      categories: categories,
      savingsTargetKobo: payload['savingsTargetKobo'] as int? ?? 0,
      savingsGoal: payload['savingsGoal'] as String? ?? 'Emergency buffer',
      aiNotes: payload['aiNotes'] as String? ?? '',
    );
  }

  TransactionDraft _transactionDraftFromPayload({
    required String rawText,
    required TransactionSource source,
    required Map<String, dynamic> payload,
  }) {
    return TransactionDraft(
      amountKobo: _intFromPayload(payload['amountKobo']),
      type: payload['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      merchantName:
          payload['merchantName'] as String? ??
          payload['description'] as String? ??
          'Merchant',
      source: source,
      rawText: rawText,
      category: payload['category'] as String? ?? 'Miscellaneous',
    );
  }

  WeeklyInsight _weeklyInsightFromPayload(Map<String, dynamic> payload) {
    return WeeklyInsight(
      id: 'ai-insight-${DateTime.now().microsecondsSinceEpoch}',
      title: payload['title'] as String? ?? 'Spending pattern needs more data',
      body:
          payload['body'] as String? ??
          'Kolo needs more transactions before it can produce a confident weekly insight.',
      createdAt: DateTime.now(),
    );
  }

  int _intFromPayload(Object? value) {
    return switch (value) {
      final int amount => amount,
      final num amount => amount.toInt(),
      _ => 0,
    };
  }

  BudgetPlan _fallbackBudget(OnboardingAnswers answers) {
    final balance = answers.currentBalanceKobo;
    return BudgetPlan(
      monthlyIncomeKobo: (balance * 2.4).round(),
      incomeType: answers.incomeFrequency.toLowerCase().contains('regular')
          ? 'regular'
          : 'irregular',
      categories: [
        BudgetCategory(
          name: 'Food & Snacks',
          emoji: '*',
          allocatedKobo: (balance * 0.28).round(),
          priority: 1,
        ),
        BudgetCategory(
          name: 'Transport',
          emoji: '*',
          allocatedKobo: (balance * 0.16).round(),
          priority: 2,
        ),
        BudgetCategory(
          name: 'Data & Airtime',
          emoji: '*',
          allocatedKobo: (balance * 0.10).round(),
          priority: 3,
        ),
        BudgetCategory(
          name: 'Savings',
          emoji: '*',
          allocatedKobo: (balance * 0.25).round(),
          priority: 0,
        ),
      ],
      savingsTargetKobo: (balance * 0.25).round(),
      savingsGoal: answers.savingsGoal ?? 'Emergency buffer',
      aiNotes:
          'Kolo used a local fallback plan because Gemini was unavailable.',
    );
  }

  String _fallbackReminder(Owing owing) {
    return '${AiFailureMessage.reminder} ${owing.person}, please send it when you can.';
  }

  WeeklyInsight _fallbackInsight() {
    return WeeklyInsight(
      id: 'ai-insight-fallback-${DateTime.now().microsecondsSinceEpoch}',
      title: 'Kolo needs a moment',
      body:
          'Kolo could not analyze spending right now. Try again when the connection settles.',
      createdAt: DateTime.now(),
    );
  }
}
