import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/data/services/direct_gemini_ai_service.dart';
import 'package:kolo/data/services/firebase_bootstrap.dart';

void main() {
  test('AI providers use direct Gemini when an env API key is configured', () {
    final container = ProviderContainer(
      overrides: [
        directGeminiApiKeyProvider.overrideWithValue('test-key'),
        firebaseBootstrapResultProvider.overrideWithValue(
          const FirebaseBootstrapResult(initialized: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(koloAiServiceProvider), isA<DirectGeminiAiService>());
    expect(
      container.read(transactionCategorizerProvider),
      isA<DirectGeminiAiService>(),
    );
    expect(
      container.read(spendingInterventionAdvisorProvider),
      isA<DirectGeminiAiService>(),
    );
    expect(
      container.read(spendingJustificationAdvisorProvider),
      isA<DirectGeminiAiService>(),
    );
    expect(container.read(smsReceivedHandlerProvider), isA<DirectGeminiAiService>());
  });
}
