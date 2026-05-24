import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kolo/data/repositories/firebase_kolo_mapper.dart';
import 'package:kolo/data/services/cloud_ai_service.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';

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
  Future<void> upsertOwing(Owing owing) async {
    await _userDoc.collection('owings').doc(owing.id).set({
      ...FirebaseKoloMapper.owingToJson(owing),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> upsertGig(GigRecord gig) async {
    await _userDoc.collection('gigs').doc(gig.id).set({
      ...FirebaseKoloMapper.gigToJson(gig),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> upsertBill(BillReminder bill) async {
    await _userDoc.collection('bills').doc(bill.id).set({
      ...FirebaseKoloMapper.billToJson(bill),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> logTransaction(TransactionRecord transaction) async {
    await _userDoc.collection('transactions').doc(transaction.id).set({
      ...FirebaseKoloMapper.transactionToJson(transaction),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _firestore.runTransaction((dbTransaction) async {
      final snapshot = await dbTransaction.get(_userDoc);
      final current = (snapshot.data()?['balanceKobo'] as int?) ?? 0;
      dbTransaction.set(_userDoc, {
        'balanceKobo': current + transaction.signedKobo,
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<BudgetPlan> generateBudget(OnboardingAnswers answers) async {
    final budget = await _aiService.generateBudget(answers);
    await updateBudget(budget);
    return budget;
  }

  @override
  Future<BudgetPlan> completeOnboarding(OnboardingAnswers answers) async {
    final budget = await _aiService.generateBudget(answers);
    await _userDoc.set({
      'balanceKobo': answers.currentBalanceKobo,
      'onboardingAnswers': {
        'incomeSource': answers.incomeSource,
        'incomeFrequency': answers.incomeFrequency,
        'currentBalanceKobo': answers.currentBalanceKobo,
        'biggestProblem': answers.biggestProblem,
        'savingsGoal': answers.savingsGoal,
      },
      'budgetPlan': FirebaseKoloMapper.budgetToJson(budget),
      'onboardingComplete': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return budget;
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
