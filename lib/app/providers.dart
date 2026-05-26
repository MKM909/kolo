import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';
import 'package:kolo/app/backend_selector.dart';
import 'package:kolo/data/repositories/cached_kolo_repository.dart';
import 'package:kolo/data/repositories/fake_auth_repository.dart';
import 'package:kolo/data/repositories/fake_kolo_repository.dart';
import 'package:kolo/data/repositories/fake_partner_repository.dart';
import 'package:kolo/data/repositories/firebase_auth_repository.dart';
import 'package:kolo/data/repositories/firebase_kolo_repository.dart';
import 'package:kolo/data/repositories/firebase_partner_repository.dart';
import 'package:kolo/data/repositories/queued_kolo_repository.dart';
import 'package:kolo/data/services/android_capability_service.dart';
import 'package:kolo/data/services/biometric_session_lock.dart';
import 'package:kolo/data/services/biometric_unlock_service.dart';
import 'package:kolo/data/services/cloud_ai_service.dart';
import 'package:kolo/data/services/connectivity_sync_retry_service.dart';
import 'package:kolo/data/services/due_bill_processor.dart';
import 'package:kolo/data/services/firebase_bootstrap.dart';
import 'package:kolo/data/services/android_permission_requester.dart';
import 'package:kolo/data/services/android_reminder_scheduler.dart';
import 'package:kolo/data/services/hive_dashboard_cache_store.dart';
import 'package:kolo/data/services/native_event_ingestor.dart';
import 'package:kolo/data/services/offline_sync_dispatcher.dart';
import 'package:kolo/data/services/offline_sync_queue.dart';
import 'package:kolo/data/services/overlay_conversation_bridge.dart';
import 'package:kolo/data/services/overlay_bubble_service.dart';
import 'package:kolo/data/services/reminder_sync_service.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/auth_repository.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';
import 'package:kolo/domain/repositories/partner_repository.dart';
import 'package:kolo/domain/services/dashboard_cache_store.dart';
import 'package:kolo/domain/services/permission_requester.dart';
import 'package:kolo/domain/services/local_spending_justification_advisor.dart';
import 'package:kolo/domain/services/reminder_scheduler.dart';
import 'package:kolo/domain/services/sms_received_handler.dart';
import 'package:kolo/domain/services/spending_justification_advisor.dart';
import 'package:kolo/domain/services/spending_intervention_advisor.dart';
import 'package:kolo/domain/services/transaction_categorizer.dart';

final firebaseBootstrapResultProvider = Provider<FirebaseBootstrapResult>((
  ref,
) {
  return const FirebaseBootstrapResult(initialized: false);
});

final permissionRequesterProvider = Provider<PermissionRequester>((ref) {
  return AndroidPermissionRequester();
});

final androidCapabilityServiceProvider = Provider<AndroidCapabilityService>((
  ref,
) {
  return AndroidCapabilityService();
});

final overlayBubbleServiceProvider = Provider<OverlayBubbleService>((ref) {
  return OverlayBubbleService();
});

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  return const AndroidReminderScheduler();
});

final reminderScheduleStoreProvider = Provider<ReminderScheduleStore>((ref) {
  if (Hive.isBoxOpen(koloReminderScheduleBoxName)) {
    return HiveReminderScheduleStore(
      Hive.box<Object?>(koloReminderScheduleBoxName),
    );
  }
  return MemoryReminderScheduleStore();
});

final biometricUnlockServiceProvider = Provider<BiometricUnlockService>((ref) {
  return BiometricUnlockService();
});

final biometricSessionLockProvider =
    ChangeNotifierProvider<BiometricSessionLock>((ref) {
      return BiometricSessionLock();
    });

final biometricSessionRequiresUnlockProvider = Provider<bool>((ref) {
  return ref.watch(biometricSessionLockProvider).requiresUnlock;
});

final transactionCategorizerProvider = Provider<TransactionCategorizer?>((ref) {
  final bootstrap = ref.watch(firebaseBootstrapResultProvider);
  if (!bootstrap.initialized) return null;
  return CloudAiService();
});

final spendingInterventionAdvisorProvider =
    Provider<SpendingInterventionAdvisor?>((ref) {
      final bootstrap = ref.watch(firebaseBootstrapResultProvider);
      if (!bootstrap.initialized) return null;
      return CloudAiService();
    });

final spendingJustificationAdvisorProvider =
    Provider<SpendingJustificationAdvisor>((ref) {
      final bootstrap = ref.watch(firebaseBootstrapResultProvider);
      if (!bootstrap.initialized) {
        return const LocalSpendingJustificationAdvisor();
      }
      return CloudAiService();
    });

final smsReceivedHandlerProvider = Provider<SmsReceivedHandler?>((ref) {
  final bootstrap = ref.watch(firebaseBootstrapResultProvider);
  if (!bootstrap.initialized) return null;
  return CloudAiService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final bootstrap = ref.watch(firebaseBootstrapResultProvider);
  if (bootstrap.initialized) return FirebaseAuthRepository();

  final repository = FakeAuthRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).watchAuthState();
});

final dashboardCacheStoreProvider = Provider<DashboardCacheStore>((ref) {
  if (Hive.isBoxOpen(koloDashboardCacheBoxName)) {
    return HiveDashboardCacheStore(
      Hive.box<Object?>(koloDashboardCacheBoxName),
    );
  }
  return MemoryDashboardCacheStore();
});

final firebaseKoloRemoteRepositoryProvider = Provider<KoloRepository?>((ref) {
  final bootstrap = ref.watch(firebaseBootstrapResultProvider);
  final authUser = ref
      .watch(authStateProvider)
      .when(data: (user) => user, error: (_, _) => null, loading: () => null);

  if (!bootstrap.initialized || authUser == null || authUser.uid.isEmpty) {
    return null;
  }

  return CachedKoloRepository(
    uid: authUser.uid,
    remote: FirebaseKoloRepository(uid: authUser.uid),
    cache: ref.watch(dashboardCacheStoreProvider),
  );
});

final koloRepositoryProvider = Provider<KoloRepository>((ref) {
  final bootstrap = ref.watch(firebaseBootstrapResultProvider);
  final authUser = ref
      .watch(authStateProvider)
      .when(data: (user) => user, error: (_, _) => null, loading: () => null);
  return KoloRepositorySelector.select(
    firebaseInitialized: bootstrap.initialized,
    firebaseUid: authUser?.uid,
    fakeBuilder: FakeKoloRepository.seeded,
    firebaseBuilder: (_) => QueuedKoloRepository(
      remote: ref.watch(firebaseKoloRemoteRepositoryProvider)!,
      queue: ref.watch(offlineSyncQueueProvider),
    ),
  );
});

final partnerRepositoryProvider = Provider<PartnerRepository>((ref) {
  final bootstrap = ref.watch(firebaseBootstrapResultProvider);
  if (bootstrap.initialized) return FirebasePartnerRepository();
  return FakePartnerRepository();
});

final dashboardProvider = StreamProvider<DashboardState>((ref) {
  return ref.watch(koloRepositoryProvider).watchDashboard();
});

final permissionStatusRefreshProvider = FutureProvider<void>((ref) async {
  final bootstrap = ref.watch(firebaseBootstrapResultProvider);
  if (!bootstrap.initialized) return;

  final dashboard = await ref.watch(dashboardProvider.future);
  final repository = ref.watch(koloRepositoryProvider);
  final requester = ref.watch(permissionRequesterProvider);

  for (final entry in dashboard.permissions.entries) {
    if (entry.key == KoloPermission.backgroundService) {
      continue;
    }

    try {
      final currentStatus = await requester.status(entry.key);
      if (currentStatus != entry.value) {
        await repository.updatePermission(entry.key, currentStatus);
      }
    } on Object {
      continue;
    }
  }
});

final offlineSyncQueueProvider = Provider<OfflineSyncQueue>((ref) {
  if (Hive.isBoxOpen(koloOfflineSyncBoxName)) {
    return OfflineSyncQueue(
      store: HiveOfflineSyncStore(Hive.box<Object?>(koloOfflineSyncBoxName)),
    );
  }
  return OfflineSyncQueue();
});

final pendingSyncOperationsProvider =
    StreamProvider<List<PendingSyncOperation>>((ref) {
      return ref.watch(offlineSyncQueueProvider).watchPendingOperations();
    });

final connectivityChangesProvider = Provider<Stream<List<ConnectivityResult>>>((
  ref,
) {
  return Connectivity().onConnectivityChanged;
});

final connectivitySyncRetryServiceProvider =
    Provider<ConnectivitySyncRetryService>((ref) {
      final service = ConnectivitySyncRetryService(
        connectivityChanges: ref.watch(connectivityChangesProvider),
        retryPending: () async {
          ref.invalidate(offlineSyncRetryProvider);
          return ref.read(offlineSyncRetryProvider.future);
        },
      );
      service.start();
      ref.onDispose(() => unawaited(service.dispose()));
      return service;
    });

final offlineSyncDispatcherProvider = Provider<OfflineSyncDispatcher>((ref) {
  return OfflineSyncDispatcher(
    queue: ref.watch(offlineSyncQueueProvider),
    repository: ref.watch(offlineSyncTargetRepositoryProvider),
  );
});

final offlineSyncTargetRepositoryProvider = Provider<KoloRepository>((ref) {
  return ref.watch(firebaseKoloRemoteRepositoryProvider) ??
      ref.watch(koloRepositoryProvider);
});

final offlineSyncRetryProvider = FutureProvider<int>((ref) async {
  final bootstrap = ref.watch(firebaseBootstrapResultProvider);
  final authUser = ref
      .watch(authStateProvider)
      .when(data: (user) => user, error: (_, _) => null, loading: () => null);
  if (bootstrap.initialized && authUser == null) return 0;

  return ref.watch(offlineSyncDispatcherProvider).retryPending();
});

final dueBillProcessorProvider = FutureProvider<int>((ref) async {
  final bootstrap = ref.watch(firebaseBootstrapResultProvider);
  final authUser = ref
      .watch(authStateProvider)
      .when(data: (user) => user, error: (_, _) => null, loading: () => null);
  if (bootstrap.initialized && authUser == null) return 0;

  return DueBillProcessor(
    repository: ref.watch(koloRepositoryProvider),
  ).process();
});

final reminderSyncProvider = FutureProvider<int>((ref) async {
  final bootstrap = ref.watch(firebaseBootstrapResultProvider);
  final authUser = ref
      .watch(authStateProvider)
      .when(data: (user) => user, error: (_, _) => null, loading: () => null);
  if (bootstrap.initialized && authUser == null) return 0;

  final dashboard = await ref.watch(dashboardProvider.future);
  return ReminderSyncService(
    scheduler: ref.watch(reminderSchedulerProvider),
    scheduleStore: ref.watch(reminderScheduleStoreProvider),
  ).sync(dashboard);
});

final nativeEventIngestorProvider = Provider<NativeEventIngestor>((ref) {
  return NativeEventIngestor(
    capabilities: ref.watch(androidCapabilityServiceProvider),
    repository: ref.watch(koloRepositoryProvider),
    overlayBubble: ref.watch(overlayBubbleServiceProvider),
    categorizer: ref.watch(transactionCategorizerProvider),
    interventionAdvisor: ref.watch(spendingInterventionAdvisorProvider),
    smsReceivedHandler: ref.watch(smsReceivedHandlerProvider),
  );
});

final nativeEventDrainProvider = FutureProvider<int>((ref) async {
  final bootstrap = ref.watch(firebaseBootstrapResultProvider);
  final authUser = ref
      .watch(authStateProvider)
      .when(data: (user) => user, error: (_, _) => null, loading: () => null);
  if (!bootstrap.initialized || authUser == null) return 0;

  return ref.watch(nativeEventIngestorProvider).drainAndProcess();
});

final overlayConversationBridgeProvider = Provider<OverlayConversationBridge>((
  ref,
) {
  final bridge = OverlayConversationBridge(
    overlayBubble: ref.watch(overlayBubbleServiceProvider),
    repository: ref.watch(koloRepositoryProvider),
    spendingAdvisor: ref.watch(spendingJustificationAdvisorProvider),
    loadDashboard: () => ref.read(dashboardProvider.future),
  );
  bridge.start();
  ref.onDispose(() => unawaited(bridge.dispose()));
  return bridge;
});
