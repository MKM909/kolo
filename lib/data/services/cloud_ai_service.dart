import 'package:cloud_functions/cloud_functions.dart';
import 'package:kolo/domain/models/models.dart';

class CloudAiService {
  CloudAiService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<String> chatWithKolo({
    required String message,
    required DashboardState context,
  }) async {
    final callable = _functions.httpsCallable('chatWithKolo');
    final response = await callable.call<Map<String, dynamic>>({
      'message': message,
      'context': _contextPayload(context),
    });
    return response.data['content'] as String? ??
        'Kolo could not think clearly right now.';
  }

  Future<BudgetPlan> generateBudget(OnboardingAnswers answers) async {
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
  }

  Future<String> interventionMessage({required DashboardState context}) async {
    final callable = _functions.httpsCallable('interventionMessage');
    final response = await callable.call<Map<String, dynamic>>({
      'context': _contextPayload(context),
    });
    return response.data['content'] as String? ??
        'Pause and check your Kolo balance before spending.';
  }

  Future<TransactionDraft> categorizeTransaction({
    required String rawText,
    required TransactionSource source,
    required DashboardState context,
  }) async {
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
  }

  Future<String> draftReminder({
    required Owing owing,
    required DashboardState context,
  }) async {
    final callable = _functions.httpsCallable('draftReminder');
    final response = await callable.call<Map<String, dynamic>>({
      'owing': {
        'person': owing.person,
        'amountKobo': owing.amountKobo,
        'note': owing.note,
      },
      'context': _contextPayload(context),
    });
    return response.data['message'] as String? ??
        'Gentle reminder about the money we noted in Kolo.';
  }

  Future<WeeklyInsight> analyzeSpending({
    required DashboardState context,
  }) async {
    final callable = _functions.httpsCallable('analyzeSpending');
    final response = await callable.call<Map<String, dynamic>>({
      'context': _contextPayload(context),
    });
    return _weeklyInsightFromPayload(response.data);
  }

  Map<String, Object?> _contextPayload(DashboardState state) {
    return {
      'balanceKobo': state.balanceKobo,
      'budgetCategories': [
        for (final category in state.budgetPlan.categories)
          {'name': category.name, 'allocatedKobo': category.allocatedKobo},
      ],
      'recentTransactions': [
        for (final tx in state.transactions.take(20))
          {
            'amountKobo': tx.amountKobo,
            'type': tx.type.name,
            'category': tx.category,
            'description': tx.description,
          },
      ],
      'vaults': [
        for (final vault in state.vaults)
          {
            'name': vault.name,
            'targetKobo': vault.targetKobo,
            'currentKobo': vault.currentKobo,
          },
      ],
      'owings': [
        for (final owing in state.owings)
          {
            'person': owing.person,
            'amountKobo': owing.amountKobo,
            'type': owing.type.name,
            'settled': owing.settled,
          },
      ],
      'bills': [
        for (final bill in state.bills)
          {
            'name': bill.name,
            'amountKobo': bill.amountKobo,
            'frequency': bill.frequency,
            'nextDue': bill.nextDue.toIso8601String(),
          },
      ],
    };
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
}
