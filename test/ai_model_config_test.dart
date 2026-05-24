import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/domain/services/ai_model_config.dart';

void main() {
  test('Gemini model catalog defaults to the requested lite model', () {
    expect(defaultGeminiModelName, 'gemini-3.1-flash-lite');
    expect(koloAiModelOptions.first.modelName, defaultGeminiModelName);
    expect(
      koloAiModelOptions.map((option) => option.modelName),
      contains('gemini-3.1-flash'),
    );
    expect(koloAiModelLabel('unknown-model'), 'Gemini 3.1 Flash Lite');
  });
}
