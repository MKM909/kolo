import 'package:kolo/data/services/offline_sync_queue.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';

class OfflineSyncDispatcher {
  const OfflineSyncDispatcher({
    required OfflineSyncQueue queue,
    required KoloRepository repository,
  }) : _queue = queue,
       _repository = repository;

  final OfflineSyncQueue _queue;
  final KoloRepository _repository;

  Future<int> retryPending() {
    return _queue.retryPending(_dispatch);
  }

  Future<bool> _dispatch(PendingSyncOperation operation) async {
    switch (operation.kind) {
      case 'transaction':
        final transaction = _transactionFromPayload(operation.payload);
        if (transaction == null) return false;
        await _repository.logTransaction(transaction);
        return true;
      default:
        return false;
    }
  }

  TransactionRecord? _transactionFromPayload(Map<String, Object?> payload) {
    final id = _string(payload['id']);
    final amountKobo = _int(payload['amountKobo']);
    final type = _enumByName(TransactionType.values, payload['type']);
    final date = DateTime.tryParse(_string(payload['date']) ?? '');
    if (id == null || amountKobo == null || type == null || date == null) {
      return null;
    }

    return TransactionRecord(
      id: id,
      amountKobo: amountKobo,
      type: type,
      category: _string(payload['category']) ?? 'Miscellaneous',
      description: _string(payload['description']) ?? 'Offline transaction',
      date: date,
      source:
          _enumByName(TransactionSource.values, payload['source']) ??
          TransactionSource.manual,
      merchantName: _string(payload['merchantName']),
      aiApproved: payload['aiApproved'] is bool
          ? payload['aiApproved'] as bool
          : null,
      aiNote: _string(payload['aiNote']),
    );
  }

  String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  T? _enumByName<T extends Enum>(List<T> values, Object? value) {
    final name = _string(value);
    if (name == null) return null;
    for (final enumValue in values) {
      if (enumValue.name == name) return enumValue;
    }
    return null;
  }
}
