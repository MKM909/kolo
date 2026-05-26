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
      'evaluateSpendingJustification',
      'categorizeTransaction',
      'onSmsReceived',
      'draftReminder',
      'analyzeSpending',
    ]) {
      expect(
        RegExp("httpsCallable\\(\\s*'$callable'\\s*,?\\s*\\)").hasMatch(source),
        isTrue,
        reason: 'Expected CloudAiService to call $callable',
      );
    }

    expect(source, contains('Future<String> interventionMessage'));
    expect(
      source,
      contains(
        'Future<SpendingJustificationDecision> evaluateSpendingJustification',
      ),
    );
    expect(source, contains('Future<TransactionDraft?> categorizeTransaction'));
    expect(source, contains('Future<bool> onSmsReceived'));
    expect(source, contains("'sourceEventId': sourceEventId"));
    expect(source, contains('Future<String> draftReminder'));
    expect(source, contains('Future<WeeklyInsight> analyzeSpending'));
    expect(source, contains("this.modelName = defaultGeminiModelName"));
    expect(source, contains("'model': _resolvedModel(modelName)"));
  });

  test(
    'CloudAiService returns the friendly chat fallback when Gemini fails',
    () {
      expect(
        AiFailureMessage.chat,
        'Having trouble thinking right now, try again in a sec.',
      );

      final source = File(
        'lib/data/services/cloud_ai_service.dart',
      ).readAsStringSync();

      expect(source, contains('on Object catch'));
      expect(source, contains('AiFailureMessage.chat'));
    },
  );

  test('CloudAiService has typed fallbacks for every Gemini callable', () {
    expect(
      AiFailureMessage.intervention,
      'Pause and check your Kolo balance before spending.',
    );
    expect(
      AiFailureMessage.reminder,
      'Gentle reminder about the money we noted in Kolo.',
    );

    final source = File(
      'lib/data/services/cloud_ai_service.dart',
    ).readAsStringSync();

    for (final marker in [
      'return _fallbackBudget(answers);',
      'return AiFailureMessage.intervention;',
      'return _fallbackSpendingJustificationDecision();',
      'return null;',
      'return _fallbackReminder(owing);',
      'return _fallbackInsight();',
    ]) {
      expect(source, contains(marker));
    }
  });
}
