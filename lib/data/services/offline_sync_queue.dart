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
}
