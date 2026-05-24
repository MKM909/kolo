import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolo/app/backend_selector.dart';
import 'package:kolo/data/repositories/fake_auth_repository.dart';
import 'package:kolo/data/repositories/fake_kolo_repository.dart';
import 'package:kolo/data/repositories/firebase_auth_repository.dart';
import 'package:kolo/data/repositories/firebase_kolo_repository.dart';
import 'package:kolo/data/services/android_capability_service.dart';
import 'package:kolo/data/services/firebase_bootstrap.dart';
import 'package:kolo/data/services/android_permission_requester.dart';
import 'package:kolo/data/services/native_event_ingestor.dart';
import 'package:kolo/data/services/overlay_bubble_service.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/repositories/auth_repository.dart';
import 'package:kolo/domain/repositories/kolo_repository.dart';
import 'package:kolo/domain/services/permission_requester.dart';

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

final koloRepositoryProvider = Provider<KoloRepository>((ref) {
  final bootstrap = ref.watch(firebaseBootstrapResultProvider);
  final authUser = ref
      .watch(authStateProvider)
      .when(data: (user) => user, error: (_, _) => null, loading: () => null);
  return KoloRepositorySelector.select(
    firebaseInitialized: bootstrap.initialized,
    firebaseUid: authUser?.uid,
    fakeBuilder: FakeKoloRepository.seeded,
    firebaseBuilder: (uid) => FirebaseKoloRepository(uid: uid),
  );
});

final dashboardProvider = StreamProvider<DashboardState>((ref) {
  return ref.watch(koloRepositoryProvider).watchDashboard();
});

final nativeEventIngestorProvider = Provider<NativeEventIngestor>((ref) {
  return NativeEventIngestor(
    capabilities: ref.watch(androidCapabilityServiceProvider),
    repository: ref.watch(koloRepositoryProvider),
    overlayBubble: ref.watch(overlayBubbleServiceProvider),
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
