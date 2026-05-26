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
      case 'balanceAdjustment':
        final adjustment = _balanceAdjustmentFromPayload(operation.payload);
        if (adjustment == null) return false;
        await _repository.adjustBalance(adjustment);
        return true;
      case 'budget':
        final budget = _budgetFromPayload(operation.payload);
        if (budget == null) return false;
        await _repository.updateBudget(budget);
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
      case 'deleteOwing':
        final owingId = _string(operation.payload['id']);
        if (owingId == null) return false;
        await _repository.deleteOwing(owingId);
        return true;
      case 'vault':
        final vault = _vaultFromPayload(operation.payload);
        if (vault == null) return false;
        await _repository.upsertVault(vault);
        return true;
      case 'deleteVault':
        final vaultId = _string(operation.payload['id']);
        if (vaultId == null) return false;
        await _repository.deleteVault(vaultId);
        return true;
      case 'watchedApp':
        final app = _watchedAppFromPayload(operation.payload);
        if (app == null) return false;
        await _repository.upsertWatchedApp(app);
        return true;
      case 'partnerShare':
        final share = _partnerShareFromPayload(operation.payload);
        if (share == null) return false;
        await _repository.upsertPartnerShare(share);
        return true;
      case 'transactionCategory':
        final transactionId = _string(operation.payload['transactionId']);
        final category = _string(operation.payload['category']);
        if (transactionId == null || category == null) return false;
        await _repository.updateTransactionCategory(
          transactionId: transactionId,
          category: category,
        );
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

  BalanceAdjustment? _balanceAdjustmentFromPayload(
    Map<String, Object?> payload,
  ) {
    final id = _string(payload['id']);
    final previousBalanceKobo = _int(payload['previousBalanceKobo']);
    final newBalanceKobo = _int(payload['newBalanceKobo']);
    final createdAt = DateTime.tryParse(_string(payload['createdAt']) ?? '');
    if (id == null ||
        previousBalanceKobo == null ||
        newBalanceKobo == null ||
        createdAt == null) {
      return null;
    }

    return BalanceAdjustment(
      id: id,
      previousBalanceKobo: previousBalanceKobo,
      newBalanceKobo: newBalanceKobo,
      note: _string(payload['note']) ?? 'Offline balance adjustment',
      createdAt: createdAt,
    );
  }

  BudgetPlan? _budgetFromPayload(Map<String, Object?> payload) {
    final monthlyIncomeKobo = _int(payload['monthlyIncomeKobo']);
    final incomeType = _string(payload['incomeType']);
    final savingsTargetKobo = _int(payload['savingsTargetKobo']);
    if (monthlyIncomeKobo == null ||
        incomeType == null ||
        savingsTargetKobo == null) {
      return null;
    }

    final rawCategories = payload['categories'];
    final categories = rawCategories is Iterable
        ? [
            for (final rawCategory in rawCategories)
              if (rawCategory is Map)
                _budgetCategoryFromPayload(
                  Map<String, Object?>.from(rawCategory),
                ),
          ].whereType<BudgetCategory>().toList()
        : <BudgetCategory>[];

    return BudgetPlan(
      monthlyIncomeKobo: monthlyIncomeKobo,
      incomeType: incomeType,
      categories: categories,
      savingsTargetKobo: savingsTargetKobo,
      savingsGoal: _string(payload['savingsGoal']) ?? 'Savings',
      aiNotes: _string(payload['aiNotes']) ?? '',
    );
  }

  BudgetCategory? _budgetCategoryFromPayload(Map<String, Object?> payload) {
    final name = _string(payload['name']);
    final allocatedKobo = _int(payload['allocatedKobo']);
    if (name == null || allocatedKobo == null) return null;

    return BudgetCategory(
      name: name,
      emoji: _string(payload['emoji']) ?? '*',
      allocatedKobo: allocatedKobo,
      priority: _int(payload['priority']) ?? 9,
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
      contributions: _vaultContributionsFromPayload(payload['contributions']),
    );
  }

  List<VaultContribution> _vaultContributionsFromPayload(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (_vaultContributionFromPayload(item) != null)
          _vaultContributionFromPayload(item)!,
    ];
  }

  VaultContribution? _vaultContributionFromPayload(Object? value) {
    if (value is! Map) return null;
    final payload = {
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
    final id = _string(payload['id']);
    final amountKobo = _int(payload['amountKobo']);
    final createdAtText = _string(payload['createdAt']);
    final createdAt = createdAtText == null
        ? null
        : DateTime.tryParse(createdAtText);
    if (id == null || amountKobo == null || createdAt == null) return null;

    return VaultContribution(
      id: id,
      amountKobo: amountKobo,
      createdAt: createdAt,
      note: _string(payload['note']),
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
      blockLevel:
          _enumByName(WatchedAppBlockLevel.values, payload['blockLevel']) ??
          WatchedAppBlockLevel.soft,
    );
  }

  PartnerShare? _partnerShareFromPayload(Map<String, Object?> payload) {
    final id = _string(payload['id']);
    final partnerEmail = _string(payload['partnerEmail']);
    final status = _enumByName(ShareStatus.values, payload['status']);
    final createdAt = DateTime.tryParse(_string(payload['createdAt']) ?? '');
    if (id == null ||
        partnerEmail == null ||
        status == null ||
        createdAt == null) {
      return null;
    }

    final revokedAtText = _string(payload['revokedAt']);
    final rawPermissions = payload['permissions'];
    return PartnerShare(
      id: id,
      partnerEmail: partnerEmail,
      status: status,
      permissions: rawPermissions is Iterable
          ? rawPermissions.map((item) => item.toString()).toSet()
          : const {},
      createdAt: createdAt,
      revokedAt: revokedAtText == null
          ? null
          : DateTime.tryParse(revokedAtText),
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
