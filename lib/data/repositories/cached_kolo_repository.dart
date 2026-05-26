import 'dart:async';

import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';
import 'package:kolo/domain/services/dashboard_cache_store.dart';
import 'package:kolo/domain/services/partner_summary_builder.dart';

class CachedKoloRepository implements KoloRepository {
  const CachedKoloRepository({
    required String uid,
    required KoloRepository remote,
    required DashboardCacheStore cache,
  }) : _uid = uid,
       _remote = remote,
       _cache = cache;

  final String _uid;
  final KoloRepository _remote;
  final DashboardCacheStore _cache;

  @override
  Stream<DashboardState> watchDashboard() {
    late StreamController<DashboardState> controller;
    StreamSubscription<DashboardState>? subscription;

    Future<void> emitCached() async {
      final cached = await _cache.load(_uid);
      if (cached != null && !controller.isClosed) {
        controller.add(cached.dashboard);
      }
    }

    controller = StreamController<DashboardState>.broadcast(
      onListen: () async {
        await emitCached();
        subscription = _remote.watchDashboard().listen(
          (dashboard) async {
            await _cache.save(
              uid: _uid,
              dashboard: dashboard,
              metadata: CachedDashboardMetadata(
                uid: _uid,
                cachedAt: DateTime.now(),
              ),
            );
            if (!controller.isClosed) controller.add(dashboard);
          },
          onError: (Object error, StackTrace stackTrace) async {
            final cached = await _cache.load(_uid);
            if (cached != null && !controller.isClosed) {
              controller.add(cached.dashboard);
              return;
            }
            if (!controller.isClosed) controller.addError(error, stackTrace);
          },
        );
      },
      onCancel: () => subscription?.cancel(),
    );

    return controller.stream;
  }

  @override
  Future<void> adjustBalance(BalanceAdjustment adjustment) {
    return _remote.adjustBalance(adjustment);
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
    return _remote.deleteBill(billId);
  }

  @override
  Future<void> deleteOwing(String owingId) {
    return _remote.deleteOwing(owingId);
  }

  @override
  Future<void> deleteVault(String vaultId) {
    return _remote.deleteVault(vaultId);
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
    return _remote.logTransaction(transaction);
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
    return _remote.updateBudget(budget);
  }

  @override
  Future<void> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) {
    return _remote.updateNotificationPreferences(preferences);
  }

  @override
  Future<void> updatePermission(
    KoloPermission permission,
    PermissionGrantState state,
  ) {
    return _remote.updatePermission(permission, state);
  }

  @override
  Future<void> updatePreferredAiModel(String modelName) {
    return _remote.updatePreferredAiModel(modelName);
  }

  @override
  Future<void> updateTransactionCategory({
    required String transactionId,
    required String category,
  }) {
    return _remote.updateTransactionCategory(
      transactionId: transactionId,
      category: category,
    );
  }

  @override
  Future<void> upsertBill(BillReminder bill) {
    return _remote.upsertBill(bill);
  }

  @override
  Future<void> upsertGig(GigRecord gig) {
    return _remote.upsertGig(gig);
  }

  @override
  Future<void> upsertOwing(Owing owing) {
    return _remote.upsertOwing(owing);
  }

  @override
  Future<void> upsertPartnerShare(PartnerShare share) {
    return _remote.upsertPartnerShare(share);
  }

  @override
  Future<void> upsertVault(SavingsVault vault) {
    return _remote.upsertVault(vault);
  }

  @override
  Future<void> upsertWatchedApp(WatchedApp app) {
    return _remote.upsertWatchedApp(app);
  }
}
