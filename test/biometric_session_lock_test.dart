import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/services/biometric_session_lock.dart';

void main() {
  test('does not require unlock before biometrics are enabled', () {
    final clock = _FakeClock(DateTime(2026, 5, 24, 9));
    final lock = BiometricSessionLock(now: clock.now);

    lock.markAppPaused();
    clock.advance(const Duration(hours: 1));

    expect(lock.requiresUnlock, isFalse);
  });

  test('requires unlock after the app is backgrounded past timeout', () {
    final clock = _FakeClock(DateTime(2026, 5, 24, 9));
    final lock = BiometricSessionLock(now: clock.now);

    lock.enable();
    lock.markAppPaused();
    clock.advance(const Duration(minutes: 6));

    expect(lock.requiresUnlock, isTrue);
  });

  test('successful unlock clears the session lock', () {
    final clock = _FakeClock(DateTime(2026, 5, 24, 9));
    final lock = BiometricSessionLock(now: clock.now);

    lock.enable();
    lock.markAppPaused();
    clock.advance(const Duration(minutes: 6));
    lock.markUnlocked();

    expect(lock.requiresUnlock, isFalse);
  });

  test('notifies listeners when unlock clears the session lock', () {
    final clock = _FakeClock(DateTime(2026, 5, 24, 9));
    final lock = BiometricSessionLock(now: clock.now);
    var notifications = 0;

    lock.addListener(() => notifications += 1);
    lock.enable();
    lock.markAppPaused();
    clock.advance(const Duration(minutes: 6));
    notifications = 0;
    lock.markUnlocked();

    expect(lock.requiresUnlock, isFalse);
    expect(notifications, 1);
  });
}

class _FakeClock {
  _FakeClock(this._now);

  DateTime _now;

  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}
