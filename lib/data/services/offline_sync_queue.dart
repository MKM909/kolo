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

abstract class OfflineSyncStore {
  Future<List<PendingSyncOperation>> load();

  Future<void> save(List<PendingSyncOperation> operations);
}

class MemoryOfflineSyncStore implements OfflineSyncStore {
  List<PendingSyncOperation> _operations = [];

  @override
  Future<List<PendingSyncOperation>> load() async {
    return List.unmodifiable(_operations);
  }

  @override
  Future<void> save(List<PendingSyncOperation> operations) async {
    _operations = List.unmodifiable(operations);
  }
}

class OfflineSyncQueue {
  OfflineSyncQueue({OfflineSyncStore? store})
    : _store = store ?? MemoryOfflineSyncStore() {
    _loaded = _load();
  }

  final OfflineSyncStore _store;
  final List<PendingSyncOperation> _operations = [];
  final StreamController<List<PendingSyncOperation>> _controller =
      StreamController<List<PendingSyncOperation>>.broadcast();
  late final Future<void> _loaded;

  Future<void> _load() async {
    _operations.addAll(await _store.load());
  }

  Future<void> _ensureLoaded() => _loaded;

  Stream<List<PendingSyncOperation>> watchPendingOperations() async* {
    await _ensureLoaded();
    yield List.unmodifiable(_operations);
    yield* _controller.stream;
  }

  Future<void> enqueue(PendingSyncOperation operation) async {
    await _ensureLoaded();
    _operations.add(operation);
    await _persist();
    _controller.add(List.unmodifiable(_operations));
  }

  Future<void> markSynced(String id) async {
    await _ensureLoaded();
    _operations.removeWhere((operation) => operation.id == id);
    await _persist();
    _controller.add(List.unmodifiable(_operations));
  }

  Future<int> retryPending(
    Future<bool> Function(PendingSyncOperation operation) sync,
  ) async {
    await _ensureLoaded();
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
      await _persist();
      _controller.add(List.unmodifiable(_operations));
    }

    return synced;
  }

  Future<void> _persist() {
    return _store.save(List.unmodifiable(_operations));
  }
}
