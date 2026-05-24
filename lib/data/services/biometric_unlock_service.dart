import 'package:local_auth/local_auth.dart';

abstract class BiometricPlatform {
  Future<bool> canAuthenticate();

  Future<bool> authenticate({required String localizedReason});
}

class LocalAuthBiometricPlatform implements BiometricPlatform {
  LocalAuthBiometricPlatform({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  @override
  Future<bool> canAuthenticate() async {
    return await _localAuthentication.isDeviceSupported() &&
        await _localAuthentication.canCheckBiometrics;
  }

  @override
  Future<bool> authenticate({required String localizedReason}) {
    return _localAuthentication.authenticate(
      localizedReason: localizedReason,
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }
}

class BiometricUnlockService {
  BiometricUnlockService({BiometricPlatform? platform})
    : _platform = platform ?? LocalAuthBiometricPlatform();

  final BiometricPlatform _platform;

  Future<bool> unlock() async {
    final available = await _platform.canAuthenticate();
    if (!available) return false;

    try {
      return await _platform.authenticate(
        localizedReason: 'Unlock Kolo to check your money',
      );
    } on Object {
      return false;
    }
  }
}
