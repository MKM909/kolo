import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/backend_selector.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';

void main() {
  test(
    'selects Firebase repository only when Firebase is ready and user exists',
    () {
      final fake = _StubRepository();
      final firebase = _StubRepository();
      String? selectedUid;

      final selected = KoloRepositorySelector.select(
        firebaseInitialized: true,
        firebaseUid: 'user-123',
        fakeBuilder: () => fake,
        firebaseBuilder: (uid) {
          selectedUid = uid;
          return firebase;
        },
      );

      expect(identical(selected, firebase), isTrue);
      expect(selectedUid, 'user-123');
    },
  );

  test(
    'falls back to fake repository until Firebase has an authenticated user',
    () {
      final fake = _StubRepository();
      var firebaseBuilt = false;

      final selected = KoloRepositorySelector.select(
        firebaseInitialized: true,
        firebaseUid: null,
        fakeBuilder: () => fake,
        firebaseBuilder: (_) {
          firebaseBuilt = true;
          return _StubRepository();
        },
      );

      expect(identical(selected, fake), isTrue);
      expect(firebaseBuilt, isFalse);
    },
  );
}

class _StubRepository implements KoloRepository {
  @override
  Future<void> adjustBalance(BalanceAdjustment adjustment) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertVault(SavingsVault vault) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertOwing(Owing owing) {
    throw UnimplementedError();
  }

  @override
  Future<BudgetPlan> completeOnboarding(OnboardingAnswers answers) {
    throw UnimplementedError();
  }

  @override
  Future<BudgetPlan> generateBudget(OnboardingAnswers answers) {
    throw UnimplementedError();
  }

  @override
  Future<void> logTransaction(TransactionRecord transaction) {
    throw UnimplementedError();
  }

  @override
  Future<AiMessage> sendAiMessage(String message) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateBudget(BudgetPlan budget) {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePermission(
    KoloPermission permission,
    PermissionGrantState state,
  ) {
    throw UnimplementedError();
  }

  @override
  Stream<DashboardState> watchDashboard() {
    throw UnimplementedError();
  }
}
