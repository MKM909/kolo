import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/providers.dart';

void main() {
  test('requires unlock provider updates when the session lock changes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final lock = container.read(biometricSessionLockProvider);

    lock.enable();
    lock.lockNow();
    expect(container.read(biometricSessionRequiresUnlockProvider), isTrue);

    lock.markUnlocked();
    expect(container.read(biometricSessionRequiresUnlockProvider), isFalse);
  });
}
