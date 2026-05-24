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
}
