import 'dart:async';
import 'dart:io';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolo/data/services/overlay_bubble_service.dart';
import 'package:kolo/data/services/overlay_conversation_bridge.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';
import 'package:kolo/domain/services/spending_justification_advisor.dart';

void main() {
  test(
    'spend-like overlay messages with an amount use spending justification',
    () async {
      final platform = _FakeOverlayWindow();
      final advisor = _RecordingSpendingAdvisor(
        decision: const SpendingJustificationDecision(
          status: SpendingDecisionStatus.caution,
          message: 'Caution: food budget is tight.',
          aiNote: 'Food caution.',
        ),
      );
      final repository = _RecordingRepository();
      final bridge = OverlayConversationBridge(
        overlayBubble: OverlayBubbleService(platform: platform),
        repository: repository,
        spendingAdvisor: advisor,
        loadDashboard: () async => _dashboard(),
        now: () => DateTime(2026, 5, 26, 12),
      );
      addTearDown(() async {
        await bridge.dispose();
        await platform.close();
      });

      bridge.start();
      platform.emit({
        'type': 'userMessage',
        'text': 'Can I spend 5000 on food?',
      });
      await pumpEventQueue();

      expect(advisor.justifications, ['Can I spend 5000 on food?']);
      expect(advisor.transactions.single.amountKobo, 500000);
      expect(advisor.transactions.single.category, 'Food & Snacks');
      expect(repository.sentChatMessages, isEmpty);
      expect(repository.recordedMessages.map((message) => message.content), [
        'Can I spend 5000 on food?',
        'Caution: food budget is tight.',
      ]);
      expect(platform.sharedData, [
        {'type': 'assistantMessage', 'text': 'Caution: food budget is tight.'},
      ]);
    },
  );

  test(
    'spend-like overlay messages without an amount ask for the amount',
    () async {
      final platform = _FakeOverlayWindow();
      final advisor = _RecordingSpendingAdvisor();
      final repository = _RecordingRepository();
      final bridge = OverlayConversationBridge(
        overlayBubble: OverlayBubbleService(platform: platform),
        repository: repository,
        spendingAdvisor: advisor,
        loadDashboard: () async => _dashboard(),
        now: () => DateTime(2026, 5, 26, 12),
      );
      addTearDown(() async {
        await bridge.dispose();
        await platform.close();
      });

      bridge.start();
      platform.emit({'type': 'userMessage', 'text': 'Can I buy food?'});
      await pumpEventQueue();

      expect(advisor.transactions, isEmpty);
      expect(platform.sharedData.single, {
        'type': 'assistantMessage',
        'text':
            'Tell me the amount and what it is for, then I can check it against your Kolo budget.',
      });
    },
  );

  test(
    'non-spend overlay messages continue through the normal AI chat',
    () async {
      final platform = _FakeOverlayWindow();
      final repository = _RecordingRepository(
        chatReply: AiMessage(
          id: 'assistant-1',
          role: AiRole.assistant,
          content: 'Your rent vault is still protected.',
          timestamp: DateTime(2026, 5, 26, 12),
          context: 'chat',
        ),
      );
      final bridge = OverlayConversationBridge(
        overlayBubble: OverlayBubbleService(platform: platform),
        repository: repository,
        spendingAdvisor: _RecordingSpendingAdvisor(),
        loadDashboard: () async => _dashboard(),
        now: () => DateTime(2026, 5, 26, 12),
      );
      addTearDown(() async {
        await bridge.dispose();
        await platform.close();
      });

      bridge.start();
      platform.emit({'type': 'userMessage', 'text': 'How are my vaults?'});
      await pumpEventQueue();

      expect(repository.sentChatMessages, ['How are my vaults?']);
      expect(platform.sharedData, [
        {
          'type': 'assistantMessage',
          'text': 'Your rent vault is still protected.',
        },
      ]);
    },
  );

  test('app starts the overlay conversation bridge', () {
    final providers = File('lib/app/providers.dart').readAsStringSync();
    final app = File('lib/app/kolo_app.dart').readAsStringSync();

    expect(providers, contains('overlayConversationBridgeProvider'));
    expect(app, contains('ref.watch(overlayConversationBridgeProvider)'));
  });
}

class _FakeOverlayWindow implements OverlayWindowPlatform {
  final _controller = StreamController<Object?>.broadcast();
  final List<Object?> sharedData = [];

  void emit(Object? data) => _controller.add(data);

  Future<void> close() => _controller.close();

  @override
  Stream<Object?> get overlayListener => _controller.stream;

  @override
  Future<Object?> shareData(Object? data) async {
    sharedData.add(data);
    return data;
  }

  @override
  Future<bool> isActive() async => true;

  @override
  Future<bool> isPermissionGranted() async => true;

  @override
  Future<bool?> requestPermission() async => true;

  @override
  Future<bool?> resizeOverlay({
    required int width,
    required int height,
    required bool enableDrag,
  }) async {
    return true;
  }

  @override
  Future<void> showOverlay({
    required int height,
    required int width,
    required OverlayAlignment alignment,
    required OverlayFlag flag,
    required String overlayTitle,
    required String overlayContent,
    required bool enableDrag,
    required PositionGravity positionGravity,
  }) async {}
}

class _RecordingSpendingAdvisor implements SpendingJustificationAdvisor {
  _RecordingSpendingAdvisor({
    this.decision = const SpendingJustificationDecision(
      status: SpendingDecisionStatus.approved,
      message: 'Approved.',
      aiNote: 'Approved.',
    ),
  });

  final SpendingJustificationDecision decision;
  final List<TransactionRecord> transactions = [];
  final List<String> justifications = [];

  @override
  Future<SpendingJustificationDecision> evaluateSpendingJustification({
    required DashboardState context,
    required TransactionRecord transaction,
    required String justification,
    String? modelName,
  }) async {
    transactions.add(transaction);
    justifications.add(justification);
    return decision;
  }
}

class _RecordingRepository implements KoloRepository {
  _RecordingRepository({AiMessage? chatReply})
    : _chatReply =
          chatReply ??
          AiMessage(
            id: 'assistant-default',
            role: AiRole.assistant,
            content: 'Kolo is listening.',
            timestamp: DateTime(2026, 5, 26, 12),
            context: 'chat',
          );

  final AiMessage _chatReply;
  final List<String> sentChatMessages = [];
  final List<AiMessage> recordedMessages = [];

  @override
  Future<void> recordAiMessage(AiMessage message) async {
    recordedMessages.add(message);
  }

  @override
  Future<AiMessage> sendAiMessage(String message) async {
    sentChatMessages.add(message);
    return _chatReply;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DashboardState _dashboard() {
  return DashboardState(
    profile: UserProfile(
      uid: 'demo-user',
      name: 'Demo',
      email: 'demo@kolo.app',
      createdAt: DateTime(2026, 5, 1),
      onboardingComplete: true,
      preferredAiModel: 'gemini-3.1-flash-lite',
    ),
    balanceKobo: 2500000,
    balanceAdjustments: const [],
    budgetPlan: const BudgetPlan(
      monthlyIncomeKobo: 6000000,
      incomeType: 'irregular',
      categories: [
        BudgetCategory(
          name: 'Food & Snacks',
          emoji: 'food',
          allocatedKobo: 1000000,
          priority: 1,
        ),
      ],
      savingsTargetKobo: 1000000,
      savingsGoal: 'Rent buffer',
      aiNotes: 'Keep food under control.',
    ),
    transactions: const [],
    aiMessages: const [],
    vaults: const [],
    owings: const [],
    gigs: const [],
    bills: const [],
    watchedApps: const [],
    partnerShares: const [],
    insights: const [],
    permissions: const {},
  );
}
