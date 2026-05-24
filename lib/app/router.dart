import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kolo/ui/features/ai_chat/ai_chat_screen.dart';
import 'package:kolo/ui/features/auth/auth_screens.dart';
import 'package:kolo/ui/features/budget/budget_screen.dart';
import 'package:kolo/ui/features/home/home_screen.dart';
import 'package:kolo/ui/features/profile/profile_screen.dart';
import 'package:kolo/ui/features/shell/kolo_shell.dart';
import 'package:kolo/ui/features/transactions/transactions_screen.dart';

GoRouter buildKoloRouter({
  bool firebaseInitialized = false,
  bool authKnown = true,
  bool signedIn = false,
  bool onboardingComplete = true,
  bool emailVerified = true,
  bool requiresBiometricUnlock = false,
}) {
  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      if (!firebaseInitialized || !authKnown) return null;

      final path = state.uri.path;
      final isAuthRoute =
          path == '/login' ||
          path == '/signup' ||
          path == '/splash' ||
          path == '/verify-email' ||
          path == '/onboarding';

      if (!signedIn && !isAuthRoute) return '/login';
      if (signedIn && !emailVerified && path != '/verify-email') {
        return '/verify-email';
      }
      if (signedIn && emailVerified && path == '/verify-email') {
        return onboardingComplete ? '/home' : '/onboarding';
      }
      if (signedIn &&
          !onboardingComplete &&
          path != '/onboarding' &&
          path != '/permissions') {
        return '/onboarding';
      }
      if (signedIn && onboardingComplete && requiresBiometricUnlock) {
        if (path != '/lock') return '/lock';
      }
      if (signedIn && !requiresBiometricUnlock && path == '/lock') {
        return '/home';
      }
      if (signedIn && (path == '/login' || path == '/signup')) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/permissions',
        builder: (context, state) => const PermissionSetupScreen(),
      ),
      GoRoute(
        path: '/lock',
        builder: (context, state) => const BiometricLockScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return KoloShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) => const TransactionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai',
                builder: (context, state) => AiChatScreen(
                  initialPrompt: state.uri.queryParameters['prompt'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/budget',
                builder: (context, state) => const BudgetScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Kolo could not open ${state.uri.path}')),
    ),
  );
}
