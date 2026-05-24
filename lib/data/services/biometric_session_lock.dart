import 'package:flutter/foundation.dart';

class BiometricSessionLock extends ChangeNotifier {
  BiometricSessionLock({
    DateTime Function()? now,
    this.timeout = const Duration(minutes: 5),
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration timeout;

  bool _enabled = false;
  bool _locked = false;
  DateTime? _pausedAt;

  bool get enabled => _enabled;

  bool get requiresUnlock {
    if (!_enabled) return false;
    if (_locked) return true;

    final pausedAt = _pausedAt;
    if (pausedAt == null) return false;
    return _now().difference(pausedAt) >= timeout;
  }

  void enable() {
    _enabled = true;
    _locked = false;
    _pausedAt = null;
    notifyListeners();
  }

  void disable() {
    _enabled = false;
    _locked = false;
    _pausedAt = null;
    notifyListeners();
  }

  void markAppPaused() {
    if (!_enabled) return;
    _pausedAt = _now();
    notifyListeners();
  }

  void markAppResumed() {
    if (!_enabled) return;
    notifyListeners();
  }

  void markUnlocked() {
    _locked = false;
    _pausedAt = null;
    notifyListeners();
  }

  void lockNow() {
    if (!_enabled) return;
    _locked = true;
    notifyListeners();
  }
}
