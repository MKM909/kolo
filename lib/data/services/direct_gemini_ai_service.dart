import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/ai_context_builder.dart';
import 'package:kolo/domain/services/ai_failure_message.dart';
import 'package:kolo/domain/services/ai_model_config.dart';
import 'package:kolo/domain/services/kolo_ai_service.dart';

class DirectGeminiAiService implements KoloAiService {
  DirectGeminiAiService({
    required String apiKey,
    Dio? dio,
    this.modelName = defaultGeminiModelName,
  }) : apiKey = apiKey.trim(),
       _dio = dio ?? Dio();

  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  final String apiKey;
  final Dio _dio;
  final String modelName;

  @override
  Future<String> chatWithKolo({
    required String message,
    required DashboardState context,
    String? modelName,
  }) async {
    try {
      final response = await _generateText(
        prompt: [
          'You are Kolo, a warm Nigerian personal finance assistant.',
          'Answer in a concise, practical way.',
          'User message: $message',
          'Financial context JSON: ${jsonEncode(_contextPayload(context))}',
        ].join('\n'),
        modelName: modelName,
      );
      return response.isEmpty ? AiFailureMessage.chat : response;
    } on Object {
      return AiFailureMessage.chat;
    }
  }

  @override
  Future<BudgetPlan> generateBudget(
    OnboardingAnswers answers, {
    String? modelName,
  }) async {
    try {
      final response = await _generateText(
        prompt: [
          'Create a Kolo starter budget for a Nigerian user.',
          'Return ONLY JSON with keys: monthlyIncomeKobo, incomeType, categories, savingsTargetKobo, savingsGoal, aiNotes.',
          'Each category must include name, emoji, allocatedKobo, priority.',
          'Answers JSON: ${jsonEncode({
            'incomeSource': answers.incomeSource,
            'incomeFrequency': answers.incomeFrequency,
            'currentBalanceKobo': answers.currentBalanceKobo,
            'biggestProblem': answers.biggestProblem,
            'savingsGoal': answers.savingsGoal,
          })}',
        ].join('\n'),
        modelName: modelName,
      );
      return _budgetFromPayload(_jsonObjectFromText(response));
    } on Object {
      return _fallbackBudget(answers);
    }
  }

  @override
  Future<String> interventionMessage({
    required DashboardState context,
    String? modelName,
  }) async {
    try {
      final response = await _generateText(
        prompt: [
          'Write one short Kolo intervention before the user spends money.',
          'Be friendly, direct, and based on the context.',
          'Financial context JSON: ${jsonEncode(_contextPayload(context))}',
        ].join('\n'),
        modelName: modelName,
      );
      return response.isEmpty ? AiFailureMessage.intervention : response;
    } on Object {
      return AiFailureMessage.intervention;
    }
  }

  @override
  Future<SpendingJustificationDecision> evaluateSpendingJustification({
    required DashboardState context,
    required TransactionRecord transaction,
    required String justification,
    String? modelName,
  }) async {
    try {
      final response = await _generateText(
        prompt: [
          'Evaluate this spending justification for Kolo.',
          'Return ONLY JSON with keys: status, message, aiNote.',
          'status must be one of approved, caution, advisedAgainst.',
          'Transaction JSON: ${jsonEncode(_transactionPayload(transaction))}',
          'Justification: $justification',
          'Financial context JSON: ${jsonEncode(_contextPayload(context))}',
        ].join('\n'),
        modelName: modelName,
      );
      return SpendingJustificationDecision.fromJson(
        _jsonObjectFromText(response),
      );
    } on Object {
      return _fallbackSpendingJustificationDecision();
    }
  }

  @override
  Future<TransactionDraft?> categorizeTransaction({
    required String rawText,
    required TransactionSource source,
    required DashboardState context,
    String? modelName,
  }) async {
    try {
      final response = await _generateText(
        prompt: [
          'Extract one Kolo transaction from this alert.',
          'Return ONLY JSON with keys: amountKobo, type, merchantName, category, balanceAfterKobo, occurredAt.',
          'type must be income or expense. Use null for unknown balanceAfterKobo or occurredAt.',
          'Alert source: ${source.name}',
          'Raw alert: $rawText',
          'Financial context JSON: ${jsonEncode(_contextPayload(context))}',
        ].join('\n'),
        modelName: modelName,
      );
      return _transactionDraftFromPayload(
        rawText: rawText,
        source: source,
        payload: _jsonObjectFromText(response),
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<bool> onSmsReceived({
    required String rawText,
    String? sourceEventId,
    String? sender,
    DateTime? receivedAt,
    required DashboardState context,
    String? modelName,
  }) async {
    return false;
  }

  @override
  Future<String> draftReminder({
    required Owing owing,
    required DashboardState context,
    String? modelName,
  }) async {
    try {
      final response = await _generateText(
        prompt: [
          'Draft a polite Kolo money reminder.',
          'Return only the message text.',
          'Owing JSON: ${jsonEncode({
            'person': owing.person,
            'amountKobo': owing.amountKobo,
            'note': owing.note,
          })}',
          'Financial context JSON: ${jsonEncode(_contextPayload(context))}',
        ].join('\n'),
        modelName: modelName,
      );
      return response.isEmpty ? _fallbackReminder(owing) : response;
    } on Object {
      return _fallbackReminder(owing);
    }
  }

  @override
  Future<WeeklyInsight> analyzeSpending({
    required DashboardState context,
    String? modelName,
  }) async {
    try {
      final response = await _generateText(
        prompt: [
          'Summarize one weekly Kolo spending insight.',
          'Return ONLY JSON with keys: title, body.',
          'Financial context JSON: ${jsonEncode(_contextPayload(context))}',
        ].join('\n'),
        modelName: modelName,
      );
      return _weeklyInsightFromPayload(_jsonObjectFromText(response));
    } on Object {
      return _fallbackInsight();
    }
  }

  Future<String> _generateText({
    required String prompt,
    String? modelName,
  }) async {
    if (apiKey.isEmpty) throw StateError('GEMINI_API_KEY is not configured.');
    final model = _resolvedModel(modelName);
    final response = await _dio.post<Object?>(
      '$_baseUrl/$model:generateContent',
      options: Options(
        headers: {
          'x-goog-api-key': apiKey,
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
      ),
      data: {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {'temperature': 0.35},
      },
    );
    return _textFromGeminiPayload(response.data).trim();
  }

  Map<String, Object?> _contextPayload(DashboardState state) {
    return AiContextBuilder.build(state);
  }

  String _resolvedModel(String? override) {
    return koloAiModelNameOrDefault(override ?? modelName);
  }

  String _textFromGeminiPayload(Object? payload) {
    final map = _mapFromObject(payload);
    final candidates = map['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';
    final first = _mapFromObject(candidates.first);
    final content = _mapFromObject(first['content']);
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return '';
    final firstPart = _mapFromObject(parts.first);
    return firstPart['text'] as String? ?? '';
  }

  Map<String, dynamic> _jsonObjectFromText(String text) {
    final trimmed = text.trim();
    final withoutFence = trimmed
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '');
    final start = withoutFence.indexOf('{');
    final end = withoutFence.lastIndexOf('}');
    if (start < 0 || end < start) return {};
    final decoded = jsonDecode(withoutFence.substring(start, end + 1));
    return _mapFromObject(decoded);
  }

  Map<String, dynamic> _mapFromObject(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      return _mapFromObject(decoded);
    }
    return {};
  }

  Map<String, Object?> _transactionPayload(TransactionRecord transaction) {
    return {
      'amountKobo': transaction.amountKobo,
      'type': transaction.type.name,
      'category': transaction.category,
      'description': transaction.description,
      'source': transaction.source.name,
      'merchantName': transaction.merchantName,
    };
  }

  BudgetPlan _budgetFromPayload(Map<String, dynamic> payload) {
    final categories = (payload['categories'] as List<dynamic>? ?? [])
        .whereType<Map<Object?, Object?>>()
        .map(
          (item) => BudgetCategory(
            name: item['name'] as String? ?? 'Miscellaneous',
            emoji: item['emoji'] as String? ?? '*',
            allocatedKobo: _intFromPayload(item['allocatedKobo']),
            priority: _intFromPayload(item['priority'], fallback: 9),
          ),
        )
        .toList();

    return BudgetPlan(
      monthlyIncomeKobo: _intFromPayload(payload['monthlyIncomeKobo']),
      incomeType: payload['incomeType'] as String? ?? 'irregular',
      categories: categories,
      savingsTargetKobo: _intFromPayload(payload['savingsTargetKobo']),
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
      balanceAfterKobo: _nullableIntFromPayload(payload['balanceAfterKobo']),
      occurredAt: _dateTimeFromPayload(payload['occurredAt']),
    );
  }

  WeeklyInsight _weeklyInsightFromPayload(Map<String, dynamic> payload) {
    return WeeklyInsight(
      id: 'direct-ai-insight-${DateTime.now().microsecondsSinceEpoch}',
      title: payload['title'] as String? ?? 'Spending pattern needs more data',
      body:
          payload['body'] as String? ??
          'Kolo needs more transactions before it can produce a confident weekly insight.',
      createdAt: DateTime.now(),
    );
  }

  int _intFromPayload(Object? value, {int fallback = 0}) {
    return switch (value) {
      final int amount => amount,
      final num amount => amount.toInt(),
      _ => fallback,
    };
  }

  int? _nullableIntFromPayload(Object? value) {
    return switch (value) {
      final int amount => amount,
      final num amount => amount.toInt(),
      _ => null,
    };
  }

  DateTime? _dateTimeFromPayload(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
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
      aiNotes: 'Kolo used a local fallback plan because Gemini was unavailable.',
    );
  }

  String _fallbackReminder(Owing owing) {
    return '${AiFailureMessage.reminder} ${owing.person}, please send it when you can.';
  }

  SpendingJustificationDecision _fallbackSpendingJustificationDecision() {
    return const SpendingJustificationDecision(
      status: SpendingDecisionStatus.caution,
      message:
          'I could not fully evaluate this right now. If it matters, log it with a note and I will keep it visible.',
      aiNote: 'Caution - Gemini unavailable, user explanation kept for history.',
    );
  }

  WeeklyInsight _fallbackInsight() {
    return WeeklyInsight(
      id: 'direct-ai-insight-fallback-${DateTime.now().microsecondsSinceEpoch}',
      title: 'Kolo needs a moment',
      body:
          'Kolo could not analyze spending right now. Try again when the connection settles.',
      createdAt: DateTime.now(),
    );
  }
}
