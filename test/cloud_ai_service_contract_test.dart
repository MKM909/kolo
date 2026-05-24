import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CloudAiService exposes every v1 Gemini callable', () {
    final source = File(
      'lib/data/services/cloud_ai_service.dart',
    ).readAsStringSync();

    for (final callable in [
      'chatWithKolo',
      'generateBudget',
      'interventionMessage',
      'categorizeTransaction',
      'draftReminder',
      'analyzeSpending',
    ]) {
      expect(source, contains("httpsCallable('$callable')"));
    }

    expect(source, contains('Future<String> interventionMessage'));
    expect(source, contains('Future<TransactionDraft> categorizeTransaction'));
    expect(source, contains('Future<String> draftReminder'));
    expect(source, contains('Future<WeeklyInsight> analyzeSpending'));
  });
}
