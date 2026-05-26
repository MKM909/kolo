import 'dart:async';

class NativeEventDrainLoop {
  NativeEventDrainLoop({
    required Future<int> Function() drain,
    Duration interval = const Duration(seconds: 2),
    Stream<void>? ticks,
  }) : _drain = drain,
       _interval = interval,
       _ticks = ticks;

  final Future<int> Function() _drain;
  final Duration _interval;
  final Stream<void>? _ticks;
  StreamSubscription<void>? _tickSubscription;
  Timer? _timer;
  bool _started = false;
  bool _draining = false;

  void start() {
    if (_started) return;
    _started = true;
    unawaited(_drainOnce());

    final ticks = _ticks;
    if (ticks != null) {
      _tickSubscription = ticks.listen((_) => unawaited(_drainOnce()));
    } else {
      _timer = Timer.periodic(_interval, (_) => unawaited(_drainOnce()));
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _tickSubscription?.cancel();
    _tickSubscription = null;
    _started = false;
  }

  Future<void> _drainOnce() async {
    if (_draining) return;
    _draining = true;
    try {
      await _drain();
    } on Object {
      // The loop is best-effort; the next tick retries native queue draining.
    } finally {
      _draining = false;
    }
  }
}
