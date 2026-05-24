import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/services/biometric_unlock_service.dart';

void main() {
  test('does not authenticate when biometrics are unavailable', () async {
    final platform = _FakeBiometricPlatform(canCheckBiometrics: false);
    final service = BiometricUnlockService(platform: platform);

    final unlocked = await service.unlock();

    expect(unlocked, isFalse);
    expect(platform.authenticateCalls, 0);
  });

  test('authenticates with the Kolo unlock reason when available', () async {
    final platform = _FakeBiometricPlatform(
      canCheckBiometrics: true,
      authenticateResult: true,
    );
    final service = BiometricUnlockService(platform: platform);

    final unlocked = await service.unlock();

    expect(unlocked, isTrue);
    expect(platform.authenticateCalls, 1);
    expect(platform.reason, 'Unlock Kolo to check your money');
  });
}

class _FakeBiometricPlatform implements BiometricPlatform {
  _FakeBiometricPlatform({
    required this.canCheckBiometrics,
    this.authenticateResult = false,
  });

  final bool canCheckBiometrics;
  final bool authenticateResult;
  int authenticateCalls = 0;
  String? reason;

  @override
  Future<bool> canAuthenticate() async => canCheckBiometrics;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    authenticateCalls += 1;
    reason = localizedReason;
    return authenticateResult;
  }
}
