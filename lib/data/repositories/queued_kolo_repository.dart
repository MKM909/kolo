import 'dart:async';

import 'package:kolo/data/services/offline_sync_queue.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';
import 'package:kolo/domain/services/ai_model_config.dart';
import 'package:kolo/domain/services/partner_summary_builder.dart';

typedef PendingOperationIdFactory = String Function(String kind);

class QueuedKoloRepository implements KoloRepository {
  QueuedKoloRepository({
    required KoloRepository remote,
    required OfflineSyncQueue queue,
    DateTime Function()? now,
    PendingOperationIdFactory? idFactory,
  }) : _remote = remote,
       _queue = queue,
       _now = now ?? DateTime.now,
       _idFactory = idFactory;

  final KoloRepository _remote;
  final OfflineSyncQueue _queue;
  final DateTime Function() _now;
  final PendingOperationIdFactory? _idFactory;
  int _idSequence = 0;

  @override
  Stream<DashboardState> watchDashboard() {
    return _remote.watchDashboard();
  }

  @override
  Future<void> adjustBalance(BalanceAdjustment adjustment) {
    return _writeOrQueue(
      kind: 'balanceAdjustment',
      payload: _balanceAdjustmentPayload(adjustment),
      write: () => _remote.adjustBalance(adjustment),
    );
  }

  @override
  Future<BudgetPlan> completeOnboarding(
    OnboardingAnswers answers, {
    BudgetPlan? budget,
  }) {
    return _remote.completeOnboarding(answers, budget: budget);
  }

  @override
  Future<void> clearAiMessages() {
    return _remote.clearAiMessages();
  }

  @override
  Future<void> deleteBill(String billId) {
    return _writeOrQueue(
      kind: 'deleteBill',
      payload: {'id': billId},
      write: () => _remote.deleteBill(billId),
    );
  }

  @override
  Future<void> deleteOwing(String owingId) {
    return _writeOrQueue(
      kind: 'deleteOwing',
      payload: {'id': owingId},
      write: () => _remote.deleteOwing(owingId),
    );
  }

  @override
  Future<void> deleteVault(String vaultId) {
    return _writeOrQueue(
      kind: 'deleteVault',
      payload: {'id': vaultId},
      write: () => _remote.deleteVault(vaultId),
    );
  }

  @override
  Future<String> draftOwingReminder(Owing owing) {
    return _remote.draftOwingReminder(owing);
  }

  @override
  Future<BudgetPlan> generateBudget(OnboardingAnswers answers) {
    return _remote.generateBudget(answers);
  }

  @override
  Future<WeeklyInsight> generateWeeklyInsight() {
    return _remote.generateWeeklyInsight();
  }

  @override
  Future<void> logTransaction(TransactionRecord transaction) {
    return _writeOrQueue(
      kind: 'transaction',
      payload: _transactionPayload(transaction),
      write: () => _remote.logTransaction(transaction),
    );
  }

  @override
  Future<PartnerSafeSummary?> publishPartnerSummary(PartnerShare share) {
    return _remote.publishPartnerSummary(share);
  }

  @override
  Future<void> recordAiMessage(AiMessage message) {
    return _remote.recordAiMessage(message);
  }

  @override
  Future<AiMessage> sendAiMessage(String message) {
    return _remote.sendAiMessage(message);
  }

  @override
  Future<void> updateBudget(BudgetPlan budget) {
    return _writeOrQueue(
      kind: 'budget',
      payload: _budgetPayload(budget),
      write: () => _remote.updateBudget(budget),
    );
  }

  @override
  Future<void> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) {
    return _writeOrQueue(
      kind: 'notificationPreferences',
      payload: preferences.toJson(),
      write: () => _remote.updateNotificationPreferences(preferences),
    );
  }

  @override
  Future<void> updatePermission(
    KoloPermission permission,
    PermissionGrantState state,
  ) {
    return _writeOrQueue(
      kind: 'permission',
      payload: {'permission': permission.name, 'state': state.name},
      write: () => _remote.updatePermission(permission, state),
    );
  }

  @override
  Future<void> updatePreferredAiModel(String modelName) {
    final normalizedModelName = koloAiModelNameOrDefault(modelName);
    return _writeOrQueue(
      kind: 'preferredAiModel',
      payload: {'modelName': normalizedModelName},
      write: () => _remote.updatePreferredAiModel(normalizedModelName),
    );
  }

  @override
  Future<void> updateTransactionCategory({
    required String transactionId,
    required String category,
  }) {
    return _writeOrQueue(
      kind: 'transactionCategory',
      payload: {'transactionId': transactionId, 'category': category},
      write: () => _remote.updateTransactionCategory(
        transactionId: transactionId,
        category: category,
      ),
    );
  }

  @override
  Future<void> upsertBill(BillReminder bill) {
    return _writeOrQueue(
      kind: 'bill',
      payload: _billPayload(bill),
      write: () => _remote.upsertBill(bill),
    );
  }

  @override
  Future<void> upsertGig(GigRecord gig) {
    return _writeOrQueue(
      kind: 'gig',
      payload: _gigPayload(gig),
      write: () => _remote.upsertGig(gig),
    );
  }

  @override
  Future<void> upsertOwing(Owing owing) {
    return _writeOrQueue(
      kind: 'owing',
      payload: _owingPayload(owing),
      write: () => _remote.upsertOwing(owing),
    );
  }

  @override
  Future<void> upsertPartnerShare(PartnerShare share) {
    return _writeOrQueue(
      kind: 'partnerShare',
      payload: _partnerSharePayload(share),
      write: () => _remote.upsertPartnerShare(share),
    );
  }

  @override
  Future<void> upsertVault(SavingsVault vault) {
    return _writeOrQueue(
      kind: 'vault',
      payload: _vaultPayload(vault),
      write: () => _remote.upsertVault(vault),
    );
  }

  @override
  Future<void> upsertWatchedApp(WatchedApp app) {
    return _writeOrQueue(
      kind: 'watchedApp',
      payload: _watchedAppPayload(app),
      write: () => _remote.upsertWatchedApp(app),
    );
  }

  Future<void> _writeOrQueue({
    required String kind,
    required Map<String, Object?> payload,
    required Future<void> Function() write,
  }) async {
    try {
      await write();
    } on Object {
      final createdAt = _now();
      await _queue.enqueue(
        PendingSyncOperation(
          id: _pendingId(kind, createdAt),
          kind: kind,
          payload: payload,
          createdAt: createdAt,
        ),
      );
    }
  }

  String _pendingId(String kind, DateTime createdAt) {
    final factory = _idFactory;
    if (factory != null) return factory(kind);

    _idSequence += 1;
    return 'pending-$kind-${createdAt.microsecondsSinceEpoch}-$_idSequence';
  }

  Map<String, Object?> _transactionPayload(TransactionRecord transaction) {
    return _withoutNulls({
      'id': transaction.id,
      'amountKobo': transaction.amountKobo,
      'type': transaction.type.name,
      'category': transaction.category,
      'description': transaction.description,
      'date': transaction.date.toIso8601String(),
      'source': transaction.source.name,
      'merchantName': transaction.merchantName,
      'aiApproved': transaction.aiApproved,
      'aiNote': transaction.aiNote,
    });
  }

  Map<String, Object?> _balanceAdjustmentPayload(BalanceAdjustment adjustment) {
    return {
      'id': adjustment.id,
      'previousBalanceKobo': adjustment.previousBalanceKobo,
      'newBalanceKobo': adjustment.newBalanceKobo,
      'note': adjustment.note,
      'createdAt': adjustment.createdAt.toIso8601String(),
    };
  }

  Map<String, Object?> _budgetPayload(BudgetPlan budget) {
    return {
      'monthlyIncomeKobo': budget.monthlyIncomeKobo,
      'incomeType': budget.incomeType,
      'savingsTargetKobo': budget.savingsTargetKobo,
      'savingsGoal': budget.savingsGoal,
      'aiNotes': budget.aiNotes,
      'categories': [
        for (final category in budget.categories)
          {
            'name': category.name,
            'emoji': category.emoji,
            'allocatedKobo': category.allocatedKobo,
            'priority': category.priority,
          },
      ],
    };
  }

  Map<String, Object?> _billPayload(BillReminder bill) {
    return {
      'id': bill.id,
      'name': bill.name,
      'amountKobo': bill.amountKobo,
      'frequency': bill.frequency,
      'nextDue': bill.nextDue.toIso8601String(),
      'active': bill.active,
    };
  }

  Map<String, Object?> _gigPayload(GigRecord gig) {
    return _withoutNulls({
      'id': gig.id,
      'client': gig.client,
      'amountKobo': gig.amountKobo,
      'date': gig.date.toIso8601String(),
      'projectType': gig.projectType,
      'note': gig.note,
    });
  }

  Map<String, Object?> _owingPayload(Owing owing) {
    return _withoutNulls({
      'id': owing.id,
      'type': owing.type.name,
      'person': owing.person,
      'amountKobo': owing.amountKobo,
      'date': owing.date.toIso8601String(),
      'settled': owing.settled,
      'note': owing.note,
      'dueDate': owing.dueDate?.toIso8601String(),
    });
  }

  Map<String, Object?> _vaultPayload(SavingsVault vault) {
    return _withoutNulls({
      'id': vault.id,
      'name': vault.name,
      'targetKobo': vault.targetKobo,
      'currentKobo': vault.currentKobo,
      'deadline': vault.deadline?.toIso8601String(),
      'contributions': [
        for (final contribution in vault.contributions)
          _vaultContributionPayload(contribution),
      ],
    });
  }

  Map<String, Object?> _vaultContributionPayload(
    VaultContribution contribution,
  ) {
    return _withoutNulls({
      'id': contribution.id,
      'amountKobo': contribution.amountKobo,
      'createdAt': contribution.createdAt.toIso8601String(),
      'note': contribution.note,
    });
  }

  Map<String, Object?> _watchedAppPayload(WatchedApp app) {
    return {
      'packageName': app.packageName,
      'displayName': app.displayName,
      'enabled': app.enabled,
      'blockLevel': app.blockLevel.name,
    };
  }

  Map<String, Object?> _partnerSharePayload(PartnerShare share) {
    final permissions = share.permissions.toList()..sort();
    return _withoutNulls({
      'id': share.id,
      'partnerEmail': share.partnerEmail,
      'status': share.status.name,
      'permissions': permissions,
      'createdAt': share.createdAt.toIso8601String(),
      'revokedAt': share.revokedAt?.toIso8601String(),
    });
  }

  Map<String, Object?> _withoutNulls(Map<String, Object?> payload) {
    return {
      for (final entry in payload.entries)
        if (entry.value != null) entry.key: entry.value,
    };
  }
}
