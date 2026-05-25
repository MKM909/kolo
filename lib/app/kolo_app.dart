import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/app/router.dart';
import 'package:kolo/data/services/firebase_bootstrap.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';

class KoloApp extends StatelessWidget {
  const KoloApp({super.key, this.firebaseBootstrapResult});

  final FirebaseBootstrapResult? firebaseBootstrapResult;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        if (firebaseBootstrapResult != null)
          firebaseBootstrapResultProvider.overrideWithValue(
            firebaseBootstrapResult!,
          ),
      ],
      child: const _KoloMaterialApp(),
    );
  }
}

class _KoloMaterialApp extends ConsumerStatefulWidget {
  const _KoloMaterialApp();

  @override
  ConsumerState<_KoloMaterialApp> createState() => _KoloMaterialAppState();
}

class _KoloMaterialAppState extends ConsumerState<_KoloMaterialApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(biometricSessionLockProvider);
    if (state == AppLifecycleState.resumed) {
      lock.markAppResumed();
    } else {
      lock.markAppPaused();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dueBillProcessorProvider);
    ref.watch(nativeEventDrainProvider);
    final router = ref.watch(koloRouterProvider);

    return MaterialApp.router(
      title: 'Kolo',
      debugShowCheckedModeBanner: false,
      theme: KoloTheme.light,
      routerConfig: router,
    );
  }
}

final koloRouterProvider = Provider<GoRouter>((ref) {
  final bootstrap = ref.watch(firebaseBootstrapResultProvider);
  final authState = ref.watch(authStateProvider);
  final authUser = authState.when(
    data: (user) => user,
    error: (_, _) => null,
    loading: () => null,
  );
  final signedIn = authUser != null;
  final emailVerified = authState.when(
    data: (user) => user?.emailVerified ?? true,
    error: (_, _) => false,
    loading: () => true,
  );
  final onboardingComplete = bootstrap.initialized && signedIn
      ? ref
            .watch(dashboardProvider)
            .when(
              data: (state) => state.profile.onboardingComplete,
              error: (_, _) => true,
              loading: () => true,
            )
      : true;
  final requiresBiometricUnlock = bootstrap.initialized && signedIn
      ? ref.watch(biometricSessionRequiresUnlockProvider)
      : false;

  return buildKoloRouter(
    firebaseInitialized: bootstrap.initialized,
    authKnown: !authState.isLoading,
    signedIn: signedIn,
    onboardingComplete: onboardingComplete,
    emailVerified: emailVerified,
    requiresBiometricUnlock: requiresBiometricUnlock,
  );
});
