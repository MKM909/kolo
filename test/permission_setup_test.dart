import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/features/auth/auth_screens.dart';

void main() {
  testWidgets('permission setup grants selected capability through repository', (
    tester,
  ) async {
    final repository = _RecordingKoloRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [koloRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: KoloTheme.light,
          home: const PermissionSetupScreen(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('permission_setup_sms')));
    await tester.pumpAndSettle();

    expect(repository.permission, KoloPermission.sms);
    expect(repository.state, PermissionGrantState.granted);
  });
}

class _RecordingKoloRepository implements KoloRepository {
  KoloPermission? permission;
  PermissionGrantState? state;

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
  ) async {
    this.permission = permission;
    this.state = state;
  }

  @override
  Stream<DashboardState> watchDashboard() {
    throw UnimplementedError();
  }
}
