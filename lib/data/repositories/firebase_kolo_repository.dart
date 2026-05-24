import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kolo/data/repositories/firebase_kolo_mapper.dart';
import 'package:kolo/data/services/cloud_ai_service.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';
import 'package:kolo/domain/services/ai_model_config.dart';
import 'package:kolo/domain/services/partner_summary_builder.dart';

class FirebaseKoloRepository implements KoloRepository {
  FirebaseKoloRepository({
    required String uid,
    FirebaseFirestore? firestore,
    CloudAiService? aiService,
  }) : _uid = uid,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _aiService = aiService ?? CloudAiService();

  final String _uid;
  final FirebaseFirestore _firestore;
  final CloudAiService _aiService;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('users').doc(_uid);

  @override
  Stream<DashboardState> watchDashboard() {
    late StreamController<DashboardState> controller;
    final subscriptions = <StreamSubscription<void>>[];
    var disposed = false;
    var emitting = false;
    var queued = false;

    Future<void> emitDashboard() async {
      if (disposed) return;
      if (emitting) {
        queued = true;
        return;
      }

      emitting = true;
      do {
        queued = false;
        try {
          final dashboard = await _loadDashboard();
          if (!disposed) controller.add(dashboard);
        } on Object catch (error, stackTrace) {
          if (!disposed) controller.addError(error, stackTrace);
        }
      } while (queued && !disposed);
      emitting = false;
    }

    controller = StreamController<DashboardState>.broadcast(
      onListen: () {
        emitDashboard();
        for (final stream in _dashboardStreams()) {
          subscriptions.add(
            stream.listen((_) => emitDashboard(), onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        disposed = true;
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream;
  }

  @override
  Future<void> adjustBalance(BalanceAdjustment adjustment) async {
    final adjustmentDoc = _userDoc
        .collection('balanceAdjustments')
        .doc(adjustment.id);
    await _firestore.runTransaction((dbTransaction) async {
      dbTransaction.set(adjustmentDoc, {
        ...FirebaseKoloMapper.balanceAdjustmentToJson(adjustment),
        'serverCreatedAt': FieldValue.serverTimestamp(),
      });
      dbTransaction.set(_userDoc, {
        'balanceKobo': adjustment.newBalanceKobo,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<void> upsertVault(SavingsVault vault) async {
    await _userDoc.collection('vaults').doc(vault.id).set({
      ...FirebaseKoloMapper.vaultToJson(vault),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteVault(String vaultId) async {
    await _userDoc.collection('vaults').doc(vaultId).delete();
  }

  @override
  Future<void> upsertOwing(Owing owing) async {
    await _userDoc.collection('owings').doc(owing.id).set({
      ...FirebaseKoloMapper.owingToJson(owing),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteOwing(String owingId) async {
    await _userDoc.collection('owings').doc(owingId).delete();
  }

  @override
  Future<void> upsertGig(GigRecord gig) async {
    final transactionId = 'gig-income-${gig.id}';
    final transaction = TransactionRecord.income(
      id: transactionId,
      amountKobo: gig.amountKobo,
      category: 'Gig Income',
      description: '${gig.client} gig',
      date: gig.date,
      source: TransactionSource.manual,
      merchantName: gig.client,
      aiNote: 'Logged from Gig Tracker.',
    );

    final transactionRef = _userDoc
        .collection('transactions')
        .doc(transactionId);
    final existing = await transactionRef.get();
    final existingAmountKobo = existing.exists
        ? ((existing.data()?['amountKobo'] as num?)?.toInt() ?? 0)
        : 0;
    final balanceDelta = transaction.amountKobo - existingAmountKobo;

    final batch = _firestore.batch();
    batch.set(_userDoc.collection('gigs').doc(gig.id), {
      ...FirebaseKoloMapper.gigToJson(gig),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(transactionRef, {
      ...FirebaseKoloMapper.transactionToJson(transaction),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (balanceDelta != 0) {
      batch.set(_userDoc, {
        'balanceKobo': FieldValue.increment(balanceDelta),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Future<void> upsertBill(BillReminder bill) async {
    await _userDoc.collection('bills').doc(bill.id).set({
      ...FirebaseKoloMapper.billToJson(bill),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteBill(String billId) async {
    await _userDoc.collection('bills').doc(billId).delete();
  }

  @override
  Future<void> upsertPartnerShare(PartnerShare share) async {
    await _userDoc.collection('partnerShares').doc(share.id).set({
      ...FirebaseKoloMapper.partnerShareToJson(share),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<PartnerSafeSummary?> publishPartnerSummary(PartnerShare share) async {
    final summaryRef = _userDoc.collection('partnerSummaries').doc(share.id);
    final dashboard = await _loadDashboard();
    final summary = PartnerSummaryBuilder.build(
      dashboard: dashboard,
      share: share,
      generatedAt: DateTime.now(),
    );
    if (summary == null) {
      await summaryRef.delete();
      return null;
    }

    await summaryRef.set({
      ...summary.toJson(),
      'ownerUid': _uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return summary;
  }

  @override
  Future<void> upsertWatchedApp(WatchedApp app) async {
    await _userDoc.collection('watchedApps').doc(app.packageName).set({
      ...FirebaseKoloMapper.watchedAppToJson(app),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> logTransaction(TransactionRecord transaction) async {
    final transactionDoc = _userDoc
        .collection('transactions')
        .doc(transaction.id);
    await _firestore.runTransaction((dbTransaction) async {
      final existingTransaction = await dbTransaction.get(transactionDoc);
      if (existingTransaction.exists) return;

      final snapshot = await dbTransaction.get(_userDoc);
      final current = (snapshot.data()?['balanceKobo'] as int?) ?? 0;
      dbTransaction.set(transactionDoc, {
        ...FirebaseKoloMapper.transactionToJson(transaction),
        'createdAt': FieldValue.serverTimestamp(),
      });
      dbTransaction.set(_userDoc, {
        'balanceKobo': current + transaction.signedKobo,
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<void> recordAiMessage(AiMessage message) async {
    await _userDoc.collection('aiMessages').doc(message.id).set({
      ...FirebaseKoloMapper.aiMessageToJson(message),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> clearAiMessages() async {
    final snapshot = await _userDoc.collection('aiMessages').get();
    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Future<String> draftOwingReminder(Owing owing) async {
    final context = await _loadDashboard();
    final draft = await _aiService.draftReminder(
      owing: owing,
      context: context,
      modelName: context.profile.preferredAiModel,
    );
    await recordAiMessage(
      AiMessage(
        id: 'ai-reminder-${owing.id}-${DateTime.now().microsecondsSinceEpoch}',
        role: AiRole.assistant,
        content: draft,
        timestamp: DateTime.now(),
        context: 'owing_reminder',
      ),
    );
    return draft;
  }

  @override
  Future<WeeklyInsight> generateWeeklyInsight() async {
    final context = await _loadDashboard();
    final insight = await _aiService.analyzeSpending(
      context: context,
      modelName: context.profile.preferredAiModel,
    );
    await _userDoc.collection('insights').doc(insight.id).set({
      ...FirebaseKoloMapper.insightToJson(insight),
      'serverCreatedAt': FieldValue.serverTimestamp(),
    });
    return insight;
  }

  @override
  Future<BudgetPlan> generateBudget(OnboardingAnswers answers) async {
    final modelName = await _preferredAiModel();
    final budget = await _aiService.generateBudget(
      answers,
      modelName: modelName,
    );
    await updateBudget(budget);
    return budget;
  }

  @override
  Future<BudgetPlan> completeOnboarding(
    OnboardingAnswers answers, {
    BudgetPlan? budget,
  }) async {
    final modelName = await _preferredAiModel();
    final acceptedBudget =
        budget ??
        await _aiService.generateBudget(answers, modelName: modelName);
    final now = DateTime.now();
    final messageDoc = _userDoc
        .collection('aiMessages')
        .doc('onboarding-${now.microsecondsSinceEpoch}');
    final onboardingMessage = AiMessage(
      id: messageDoc.id,
      role: AiRole.assistant,
      content:
          'Your first Kolo budget is ready. I kept ${answers.biggestProblem.toLowerCase()} in view and protected ${acceptedBudget.savingsGoal}.',
      timestamp: now,
      context: 'onboarding',
    );

    final batch = _firestore.batch();
    batch.set(_userDoc, {
      'balanceKobo': answers.currentBalanceKobo,
      'onboardingAnswers': {
        'incomeSource': answers.incomeSource,
        'incomeFrequency': answers.incomeFrequency,
        'currentBalanceKobo': answers.currentBalanceKobo,
        'biggestProblem': answers.biggestProblem,
        'savingsGoal': answers.savingsGoal,
      },
      'budgetPlan': FirebaseKoloMapper.budgetToJson(acceptedBudget),
      'onboardingComplete': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(messageDoc, {
      ...FirebaseKoloMapper.aiMessageToJson(onboardingMessage),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return acceptedBudget;
  }

  @override
  Future<AiMessage> sendAiMessage(String message) async {
    final messages = _userDoc.collection('aiMessages');
    final now = DateTime.now();
    final userDoc = messages.doc();
    final userMessage = AiMessage(
      id: userDoc.id,
      role: AiRole.user,
      content: message,
      timestamp: now,
      context: 'chat',
    );
    await userDoc.set({
      ...FirebaseKoloMapper.aiMessageToJson(userMessage),
      'createdAt': FieldValue.serverTimestamp(),
    });

    final context = await _loadDashboard();
    final response = await _aiService.chatWithKolo(
      message: message,
      context: context,
      modelName: context.profile.preferredAiModel,
    );
    final assistantDoc = messages.doc();
    final assistantMessage = AiMessage(
      id: assistantDoc.id,
      role: AiRole.assistant,
      content: response,
      timestamp: DateTime.now(),
      context: 'chat',
    );
    await assistantDoc.set({
      ...FirebaseKoloMapper.aiMessageToJson(assistantMessage),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return assistantMessage;
  }

  @override
  Future<void> updateBudget(BudgetPlan budget) async {
    await _userDoc.set({
      'budgetPlan': FirebaseKoloMapper.budgetToJson(budget),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updatePermission(
    KoloPermission permission,
    PermissionGrantState state,
  ) async {
    await _userDoc.set({
      'permissions': {permission.name: state.name},
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updatePreferredAiModel(String modelName) async {
    await _userDoc.set({
      'preferredAiModel': koloAiModelNameOrDefault(modelName),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    await _userDoc.set({
      'notificationPreferences': preferences.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  List<Stream<void>> _dashboardStreams() {
    return [
      _userDoc.snapshots().map((_) {}),
      _collection('balanceAdjustments').snapshots().map((_) {}),
      _collection('transactions').snapshots().map((_) {}),
      _collection('aiMessages').snapshots().map((_) {}),
      _collection('vaults').snapshots().map((_) {}),
      _collection('owings').snapshots().map((_) {}),
      _collection('gigs').snapshots().map((_) {}),
      _collection('bills').snapshots().map((_) {}),
      _collection('watchedApps').snapshots().map((_) {}),
      _collection('partnerShares').snapshots().map((_) {}),
      _collection('insights').snapshots().map((_) {}),
    ];
  }

  CollectionReference<Map<String, dynamic>> _collection(String name) {
    return _userDoc.collection(name);
  }

  Future<String> _preferredAiModel() async {
    final snapshot = await _userDoc.get();
    return koloAiModelNameOrDefault(
      snapshot.data()?['preferredAiModel'] as String?,
    );
  }

  Future<DashboardState> _loadDashboard() async {
    final userSnapshot = await _userDoc.get();
    final results = await Future.wait([
      _orderedCollection('balanceAdjustments', 'createdAt'),
      _orderedCollection('transactions', 'date'),
      _orderedCollection('aiMessages', 'timestamp'),
      _orderedCollection('vaults', 'name', descending: false),
      _orderedCollection('owings', 'date'),
      _orderedCollection('gigs', 'date'),
      _orderedCollection('bills', 'nextDue', descending: false),
      _orderedCollection('watchedApps', 'displayName', descending: false),
      _orderedCollection('partnerShares', 'createdAt'),
      _orderedCollection('insights', 'createdAt'),
    ]);

    return FirebaseKoloMapper.dashboardFromPayload(
      uid: _uid,
      user: userSnapshot.data() ?? const {},
      balanceAdjustments: results[0],
      transactions: results[1],
      aiMessages: results[2],
      vaults: results[3],
      owings: results[4],
      gigs: results[5],
      bills: results[6],
      watchedApps: results[7],
      partnerShares: results[8],
      insights: results[9],
      now: DateTime.now(),
    );
  }

  Future<List<Map<String, dynamic>>> _orderedCollection(
    String collection,
    String field, {
    bool descending = true,
  }) async {
    final snapshot = await _collection(
      collection,
    ).orderBy(field, descending: descending).limit(100).get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList(growable: false);
  }
}
