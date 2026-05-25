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
      case 'bill':
        final bill = _billFromPayload(operation.payload);
        if (bill == null) return false;
        await _repository.upsertBill(bill);
        return true;
      case 'deleteBill':
        final billId = _string(operation.payload['id']);
        if (billId == null) return false;
        await _repository.deleteBill(billId);
        return true;
      case 'gig':
        final gig = _gigFromPayload(operation.payload);
        if (gig == null) return false;
        await _repository.upsertGig(gig);
        return true;
      case 'owing':
        final owing = _owingFromPayload(operation.payload);
        if (owing == null) return false;
        await _repository.upsertOwing(owing);
        return true;
      case 'vault':
        final vault = _vaultFromPayload(operation.payload);
        if (vault == null) return false;
        await _repository.upsertVault(vault);
        return true;
      case 'watchedApp':
        final app = _watchedAppFromPayload(operation.payload);
        if (app == null) return false;
        await _repository.upsertWatchedApp(app);
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

  BillReminder? _billFromPayload(Map<String, Object?> payload) {
    final id = _string(payload['id']);
    final name = _string(payload['name']);
    final amountKobo = _int(payload['amountKobo']);
    final nextDue = DateTime.tryParse(_string(payload['nextDue']) ?? '');
    if (id == null || name == null || amountKobo == null || nextDue == null) {
      return null;
    }

    return BillReminder(
      id: id,
      name: name,
      amountKobo: amountKobo,
      frequency: _string(payload['frequency']) ?? 'monthly',
      nextDue: nextDue,
      active: _bool(payload['active']) ?? true,
    );
  }

  GigRecord? _gigFromPayload(Map<String, Object?> payload) {
    final id = _string(payload['id']);
    final client = _string(payload['client']);
    final amountKobo = _int(payload['amountKobo']);
    final date = DateTime.tryParse(_string(payload['date']) ?? '');
    if (id == null || client == null || amountKobo == null || date == null) {
      return null;
    }

    return GigRecord(
      id: id,
      client: client,
      amountKobo: amountKobo,
      date: date,
      projectType: _string(payload['projectType']) ?? 'Gig work',
      note: _string(payload['note']),
    );
  }

  Owing? _owingFromPayload(Map<String, Object?> payload) {
    final id = _string(payload['id']);
    final type = _enumByName(OwingType.values, payload['type']);
    final person = _string(payload['person']);
    final amountKobo = _int(payload['amountKobo']);
    final date = DateTime.tryParse(_string(payload['date']) ?? '');
    if (id == null ||
        type == null ||
        person == null ||
        amountKobo == null ||
        date == null) {
      return null;
    }

    final dueDateText = _string(payload['dueDate']);
    return Owing(
      id: id,
      type: type,
      person: person,
      amountKobo: amountKobo,
      date: date,
      settled: _bool(payload['settled']) ?? false,
      note: _string(payload['note']),
      dueDate: dueDateText == null ? null : DateTime.tryParse(dueDateText),
    );
  }

  SavingsVault? _vaultFromPayload(Map<String, Object?> payload) {
    final id = _string(payload['id']);
    final name = _string(payload['name']);
    final targetKobo = _int(payload['targetKobo']);
    final currentKobo = _int(payload['currentKobo']);
    if (id == null ||
        name == null ||
        targetKobo == null ||
        currentKobo == null) {
      return null;
    }

    final deadlineText = _string(payload['deadline']);
    return SavingsVault(
      id: id,
      name: name,
      targetKobo: targetKobo,
      currentKobo: currentKobo,
      deadline: deadlineText == null ? null : DateTime.tryParse(deadlineText),
    );
  }

  WatchedApp? _watchedAppFromPayload(Map<String, Object?> payload) {
    final packageName = _string(payload['packageName']);
    final displayName = _string(payload['displayName']);
    if (packageName == null || displayName == null) return null;

    return WatchedApp(
      packageName: packageName,
      displayName: displayName,
      enabled: _bool(payload['enabled']) ?? false,
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

  bool? _bool(Object? value) {
    return value is bool ? value : null;
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
