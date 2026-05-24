import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/domain/services/ai_failure_message.dart';

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

  test('CloudAiService returns the friendly chat fallback when Gemini fails', () {
    expect(
      AiFailureMessage.chat,
      'Having trouble thinking right now, try again in a sec.',
    );

    final source = File(
      'lib/data/services/cloud_ai_service.dart',
    ).readAsStringSync();

    expect(source, contains('on Object catch'));
    expect(source, contains('AiFailureMessage.chat'));
  });
}
