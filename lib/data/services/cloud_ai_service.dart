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
}
