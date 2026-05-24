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

class _KoloMaterialApp extends ConsumerWidget {
  const _KoloMaterialApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
  return buildKoloRouter(
    firebaseInitialized: bootstrap.initialized,
    authKnown: !authState.isLoading,
    signedIn: authState.when(
      data: (user) => user != null,
      error: (_, _) => false,
      loading: () => false,
    ),
  );
});
