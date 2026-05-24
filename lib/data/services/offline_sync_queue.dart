import 'dart:async';

class PendingSyncOperation {
  const PendingSyncOperation({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String kind;
  final Map<String, Object?> payload;
  final DateTime createdAt;
}

class OfflineSyncQueue {
  final List<PendingSyncOperation> _operations = [];
  final StreamController<List<PendingSyncOperation>> _controller =
      StreamController<List<PendingSyncOperation>>.broadcast();

  Stream<List<PendingSyncOperation>> watchPendingOperations() async* {
    yield List.unmodifiable(_operations);
    yield* _controller.stream;
  }

  Future<void> enqueue(PendingSyncOperation operation) async {
    _operations.add(operation);
    _controller.add(List.unmodifiable(_operations));
  }

  Future<void> markSynced(String id) async {
    _operations.removeWhere((operation) => operation.id == id);
    _controller.add(List.unmodifiable(_operations));
  }

  Future<int> retryPending(
    Future<bool> Function(PendingSyncOperation operation) sync,
  ) async {
    var synced = 0;
    final completedIds = <String>{};

    for (final operation in List<PendingSyncOperation>.from(_operations)) {
      try {
        if (await sync(operation)) {
          completedIds.add(operation.id);
          synced += 1;
        }
      } on Object {
        // Keep failed operations queued for the next retry window.
      }
    }

    if (completedIds.isNotEmpty) {
      _operations.removeWhere(
        (operation) => completedIds.contains(operation.id),
      );
      _controller.add(List.unmodifiable(_operations));
    }

    return synced;
  }
}
