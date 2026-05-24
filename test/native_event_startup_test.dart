import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/data/services/firebase_bootstrap.dart';

void main() {
  test('native event drain is idle before Firebase auth is ready', () async {
    final container = ProviderContainer(
      overrides: [
        firebaseBootstrapResultProvider.overrideWithValue(
          const FirebaseBootstrapResult(initialized: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(nativeEventDrainProvider.future), 0);
  });

  test('native event ingestor is wired to the overlay bubble service', () {
    final providersSource = File('lib/app/providers.dart').readAsStringSync();

    expect(providersSource, contains('overlayBubbleServiceProvider'));
    expect(
      providersSource,
      contains('overlayBubble: ref.watch(overlayBubbleServiceProvider)'),
    );
  });

  test('native event ingestor is wired to Gemini categorization', () {
    final providersSource = File('lib/app/providers.dart').readAsStringSync();

    expect(providersSource, contains('transactionCategorizerProvider'));
    expect(
      providersSource,
      contains('categorizer: ref.watch(transactionCategorizerProvider)'),
    );
  });
}
