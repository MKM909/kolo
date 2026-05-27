import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/services/direct_gemini_ai_service.dart';
import 'package:kolo/domain/models/models.dart';

void main() {
  test('chat posts to the selected Gemini model with the API key header', () async {
    final adapter = _GeminiAdapter(
      text: 'You can, but keep food under budget.',
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final service = DirectGeminiAiService(apiKey: 'test-key', dio: dio);

    final reply = await service.chatWithKolo(
      message: 'Can I buy shawarma?',
      context: _dashboard(),
      modelName: 'gemini-3.1-flash',
    );

    expect(reply, 'You can, but keep food under budget.');
    expect(
      adapter.lastUri.toString(),
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash:generateContent',
    );
    expect(adapter.lastHeaders['x-goog-api-key'], 'test-key');
    expect(adapter.lastBody['contents'], isA<List<Object?>>());
    expect(jsonEncode(adapter.lastBody), contains('Can I buy shawarma?'));
    expect(jsonEncode(adapter.lastBody), contains('balanceKobo'));
  });

  test('generateBudget parses JSON returned from Gemini text', () async {
    final adapter = _GeminiAdapter(
      text:
          '```json\n'
          '{'
          '"monthlyIncomeKobo":15000000,'
          '"incomeType":"irregular",'
          '"categories":[{"name":"Food & Snacks","emoji":"*","allocatedKobo":4200000,"priority":1}],'
          '"savingsTargetKobo":3000000,'
          '"savingsGoal":"Laptop",'
          '"aiNotes":"Protect savings first."'
          '}\n'
          '```',
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final service = DirectGeminiAiService(apiKey: 'test-key', dio: dio);

    final budget = await service.generateBudget(
      const OnboardingAnswers(
        incomeSource: 'freelance design',
        incomeFrequency: 'irregular',
        currentBalanceKobo: 5000000,
        biggestProblem: 'impulse spending',
        savingsGoal: 'Laptop',
      ),
    );

    expect(budget.monthlyIncomeKobo, 15000000);
    expect(budget.categories.single.name, 'Food & Snacks');
    expect(budget.savingsGoal, 'Laptop');
    expect(budget.aiNotes, 'Protect savings first.');
  });
}

class _GeminiAdapter implements HttpClientAdapter {
  _GeminiAdapter({required this.text});

  final String text;
  late Uri lastUri;
  late Map<String, dynamic> lastHeaders;
  late Map<String, dynamic> lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastUri = options.uri;
    lastHeaders = options.headers;
    lastBody = Map<String, dynamic>.from(options.data as Map);
    return ResponseBody.fromString(
      jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': text},
              ],
            },
          },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

DashboardState _dashboard() {
  final now = DateTime(2026, 5, 26);
  return DashboardState(
    profile: UserProfile(
      uid: 'user-1',
      name: 'Micah',
      email: 'micah@example.com',
      createdAt: now,
      onboardingComplete: true,
    ),
    balanceKobo: 12500000,
    balanceAdjustments: const [],
    budgetPlan: const BudgetPlan(
      monthlyIncomeKobo: 15000000,
      incomeType: 'irregular',
      categories: [
        BudgetCategory(
          name: 'Food & Snacks',
          emoji: '*',
          allocatedKobo: 4000000,
          priority: 1,
        ),
      ],
      savingsTargetKobo: 3000000,
      savingsGoal: 'Laptop',
      aiNotes: 'Keep snacks controlled.',
    ),
    transactions: [
      TransactionRecord.expense(
        id: 'tx-1',
        amountKobo: 250000,
        category: 'Food & Snacks',
        description: 'Lunch',
        date: now,
        source: TransactionSource.manual,
      ),
    ],
    aiMessages: const [],
    vaults: const [],
    owings: const [],
    gigs: const [],
    bills: const [],
    watchedApps: const [],
    partnerShares: const [],
    insights: const [],
    permissions: const {},
  );
}
