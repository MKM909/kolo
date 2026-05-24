class BiometricSessionLock {
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
  }

  void disable() {
    _enabled = false;
    _locked = false;
    _pausedAt = null;
  }

  void markAppPaused() {
    if (!_enabled) return;
    _pausedAt = _now();
  }

  void markUnlocked() {
    _locked = false;
    _pausedAt = null;
  }

  void lockNow() {
    if (_enabled) _locked = true;
  }
}
