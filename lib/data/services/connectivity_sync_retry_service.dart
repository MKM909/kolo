import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivitySyncRetryService {
  ConnectivitySyncRetryService({
    required Stream<List<ConnectivityResult>> connectivityChanges,
    required Future<int> Function() retryPending,
  }) : _connectivityChanges = connectivityChanges,
       _retryPending = retryPending;

  final Stream<List<ConnectivityResult>> _connectivityChanges;
  final Future<int> Function() _retryPending;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _retrying = false;

  void start() {
    _subscription ??= _connectivityChanges.listen(_handleConnectivityChange);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _handleConnectivityChange(
    List<ConnectivityResult> results,
  ) async {
    if (_retrying || !_hasConnection(results)) return;

    _retrying = true;
    try {
      await _retryPending();
    } on Object {
      // Queued operations stay pending; the next connectivity change retries.
    } finally {
      _retrying = false;
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((result) => result != ConnectivityResult.none);
  }
}
