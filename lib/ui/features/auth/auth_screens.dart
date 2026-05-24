import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/core/widgets/kolo_scaffold.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const KoloGradientScaffold(
      child: Center(
        child: Text(
          'Kolo',
          style: TextStyle(
            fontFamily: 'Sora',
            fontSize: 42,
            fontWeight: FontWeight.w800,
            color: KoloColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AuthPanel(
      mode: _AuthMode.login,
      title: 'Welcome back',
      subtitle: 'Log in with your Kolo email.',
    );
  }
}

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AuthPanel(
      mode: _AuthMode.signup,
      title: 'Create your Kolo',
      subtitle: 'Start with email, then Kolo will build your first budget.',
    );
  }
}

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _loading = false;
  String? _message;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final authUser = ref
        .watch(authStateProvider)
        .maybeWhen(data: (user) => user, orElse: () => null);

    return KoloGradientScaffold(
      key: const Key('email_verification_screen'),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KoloCard(
                child: Column(
                  children: [
                    Container(
                      height: 64,
                      width: 64,
                      decoration: const BoxDecoration(
                        color: KoloColors.primaryPastel,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        color: KoloColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Verify your email',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      authUser?.email.isNotEmpty == true
                          ? 'We sent a verification link to ${authUser!.email}.'
                          : 'We sent a verification link to your email.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: KoloColors.textSecondary),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: KoloColors.primary),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: KoloColors.expense),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      key: const Key('check_email_verification'),
                      onPressed: _loading ? null : _checkVerification,
                      icon: const Icon(Icons.refresh),
                      label: Text(_loading ? 'Checking' : 'I verified it'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('resend_verification_email'),
                      onPressed: _loading ? null : _resendVerification,
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('Resend link'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resendVerification() async {
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      if (!mounted) return;
      setState(() => _message = 'Verification link sent.');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkVerification() async {
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      final user = await ref.read(authRepositoryProvider).reloadCurrentUser();
      if (!mounted) return;
      if (user?.emailVerified == true) {
        GoRouter.maybeOf(context)?.go('/home');
      } else {
        setState(() => _message = 'Still waiting for verification.');
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _OnboardingSetupScreen();
  }
}

class PermissionSetupScreen extends StatelessWidget {
  const PermissionSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PermissionSetupPanel();
  }
}

class BiometricSetupScreen extends ConsumerStatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  ConsumerState<BiometricSetupScreen> createState() =>
      _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends ConsumerState<BiometricSetupScreen> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return KoloGradientScaffold(
      key: const Key('biometric_setup_screen'),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KoloCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 72,
                      width: 72,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: KoloColors.primaryPastel,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x337C3AED),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        color: KoloColors.primary,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Protect Kolo',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use your fingerprint to keep your balance, budget, and AI money context private when you return to the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: KoloColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        key: const Key('biometric_setup_error'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: KoloColors.expense),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      key: const Key('biometric_setup_enable'),
                      onPressed: _loading ? null : _enableBiometrics,
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.lock_outline_rounded),
                      label: Text(_loading ? 'Checking' : 'Enable fingerprint'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const Key('biometric_setup_skip'),
                      onPressed: _loading ? null : _continueToPermissions,
                      child: const Text('Skip for now'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enableBiometrics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final unlocked = await ref.read(biometricUnlockServiceProvider).unlock();
      if (!mounted) return;
      if (unlocked) {
        ref.read(biometricSessionLockProvider).enable();
        _continueToPermissions();
      } else {
        setState(() => _error = 'Biometric setup was not available.');
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _continueToPermissions() {
    GoRouter.maybeOf(context)?.go('/permissions');
  }
}

class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() =>
      _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return KoloGradientScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              KoloCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 64,
                      width: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: KoloColors.primaryPastel,
                      ),
                      child: const Icon(
                        Icons.fingerprint,
                        color: KoloColors.primary,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Unlock Kolo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your money context is private. Confirm it is you to continue.',
                      textAlign: TextAlign.center,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: KoloColors.expense),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const Key('biometric_lock_unlock'),
                        onPressed: _loading ? null : _unlock,
                        icon: const Icon(Icons.lock_open_rounded),
                        label: Text(_loading ? 'Checking' : 'Unlock'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _unlock() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final unlocked = await ref.read(biometricUnlockServiceProvider).unlock();
      if (!mounted) return;
      if (unlocked) {
        ref.read(biometricSessionLockProvider).markUnlocked();
        GoRouter.maybeOf(context)?.go('/home');
      } else {
        setState(() {
          _error = 'Biometric unlock was not available.';
        });
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}

enum _AuthMode { login, signup }

class _AuthPanel extends ConsumerStatefulWidget {
  const _AuthPanel({
    required this.mode,
    required this.title,
    required this.subtitle,
  });

  final _AuthMode mode;
  final String title;
  final String subtitle;

  @override
  ConsumerState<_AuthPanel> createState() => _AuthPanelState();
}

class _AuthPanelState extends ConsumerState<_AuthPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  bool get _isSignup => widget.mode == _AuthMode.signup;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KoloGradientScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).vertical -
                  48,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kolo', style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: 24),
                KoloCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(widget.subtitle),
                        const SizedBox(height: 24),
                        if (_isSignup) ...[
                          TextFormField(
                            key: const Key('auth_name'),
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter your name'
                                : null,
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          key: const Key('auth_email'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) =>
                              value == null || !value.contains('@')
                              ? 'Enter a valid email'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('auth_password'),
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) =>
                              value == null || value.length < 6
                              ? 'Use at least 6 characters'
                              : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(color: KoloColors.expense),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            key: const Key('auth_continue'),
                            onPressed: _loading ? null : _submit,
                            child: Text(_loading ? 'Please wait' : 'Continue'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: const Key('auth_google_sign_in'),
                            onPressed: _loading ? null : _signInWithGoogle,
                            icon: const Icon(Icons.account_circle_outlined),
                            label: const Text('Continue with Google'),
                          ),
                        ),
                        if (!_isSignup) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              key: const Key('auth_biometric_unlock'),
                              onPressed: _loading
                                  ? null
                                  : _unlockWithBiometrics,
                              icon: const Icon(Icons.fingerprint),
                              label: const Text('Unlock with biometrics'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authRepositoryProvider);
      if (_isSignup) {
        await auth.createUserWithEmail(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
        await auth.sendEmailVerification();
      } else {
        await auth.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }

      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      router?.go(_isSignup ? '/verify-email' : '/home');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();

      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      router?.go(_isSignup ? '/onboarding' : '/home');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _unlockWithBiometrics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final unlocked = await ref.read(biometricUnlockServiceProvider).unlock();
      if (!mounted) return;
      if (unlocked) {
        GoRouter.maybeOf(context)?.go('/home');
      } else {
        setState(() {
          _error = 'Biometric unlock was not available.';
        });
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}

class _OnboardingSetupScreen extends ConsumerStatefulWidget {
  const _OnboardingSetupScreen();

  @override
  ConsumerState<_OnboardingSetupScreen> createState() =>
      _OnboardingSetupScreenState();
}

class _OnboardingSetupScreenState
    extends ConsumerState<_OnboardingSetupScreen> {
  static const _stepCount = 6;

  final _incomeController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _balanceController = TextEditingController();
  final _problemController = TextEditingController();
  final _savingsGoalController = TextEditingController();
  int _step = 0;
  bool _submitting = false;
  String? _error;
  BudgetPlan? _previewBudget;
  OnboardingAnswers? _previewAnswers;

  @override
  void dispose() {
    _incomeController.dispose();
    _frequencyController.dispose();
    _balanceController.dispose();
    _problemController.dispose();
    _savingsGoalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KoloGradientScaffold(
      child: Column(
        children: [
          const SizedBox(height: 18),
          _ProgressDots(currentStep: _step, count: _stepCount),
          Expanded(
            flex: 3,
            child: Center(
              child: Container(
                key: const Key('onboarding_kolo_bubble'),
                height: 118,
                width: 118,
                decoration: const BoxDecoration(
                  color: KoloColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x557C3AED),
                      blurRadius: 28,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 52,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 7,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: const BoxDecoration(
                color: KoloColors.surfaceWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x20000000),
                    blurRadius: 40,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              child: _previewBudget == null
                  ? _QuestionPanel(
                      assistantText: _assistantText,
                      previousAnswer: _previousAnswer,
                      showPreviousAnswer: _step > 0,
                      title: _stepTitle,
                      subtitle: _stepSubtitle,
                      content: _stepContent(),
                      error: _error,
                      submitting: _submitting,
                      buttonLabel: _buttonLabel,
                      onNext: _advance,
                    )
                  : _OnboardingBudgetPreview(
                      budget: _previewBudget!,
                      saving: _submitting,
                      error: _error,
                      onAccept: _acceptBudget,
                      onBack: _submitting ? null : _clearPreview,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepContent() {
    if (_step == 0) {
      return const Center(
        child: Text(
          'Before we start, I need the money context that makes advice useful: where money comes from, how often, what you have now, what keeps leaking, and what you want protected.',
          textAlign: TextAlign.center,
          style: TextStyle(color: KoloColors.textSecondary, height: 1.45),
        ),
      );
    }
    if (_step == 1) {
      return TextField(
        key: const Key('onboarding_income_source'),
        controller: _incomeController,
        decoration: const InputDecoration(
          labelText: 'Example: freelance design, allowance, salary',
          prefixIcon: Icon(Icons.work_outline),
        ),
      );
    }
    if (_step == 2) {
      return _FreeTextStep(
        fieldKey: const Key('onboarding_income_frequency'),
        controller: _frequencyController,
        labelText: 'Example: weekly, monthly, or it comes when it comes',
        icon: Icons.calendar_today_outlined,
        suggestions: const ['Weekly', 'Monthly', 'Irregular gigs'],
        onSuggestion: (value) {
          setState(() => _frequencyController.text = value);
        },
      );
    }
    if (_step == 3) {
      return TextField(
        key: const Key('onboarding_balance'),
        controller: _balanceController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Current balance',
          prefixText: 'NGN ',
        ),
      );
    }
    if (_step == 4) {
      return _FreeTextStep(
        fieldKey: const Key('onboarding_biggest_problem'),
        controller: _problemController,
        labelText: 'Example: impulse snacks, transport, inconsistent income',
        icon: Icons.psychology_alt_outlined,
        suggestions: const ['Food spending', 'Transport leaks', 'Impulse buys'],
        onSuggestion: (value) {
          setState(() => _problemController.text = value);
        },
      );
    }
    return _FreeTextStep(
      fieldKey: const Key('onboarding_savings_goal'),
      controller: _savingsGoalController,
      labelText: 'Example: laptop, rent, emergency buffer',
      icon: Icons.lock_outline,
      suggestions: const ['New laptop', 'Emergency buffer', 'Rent'],
      onSuggestion: (value) {
        setState(() => _savingsGoalController.text = value);
      },
    );
  }

  Future<void> _advance() async {
    setState(() => _error = null);
    if (_step < _stepCount - 1) {
      setState(() => _step += 1);
      return;
    }

    final amountKobo = MoneyFormatter.parseNairaToKobo(
      _balanceController.text.trim(),
    );
    final incomeSource = _incomeController.text.trim();
    final incomeFrequency = _frequencyController.text.trim();
    final biggestProblem = _problemController.text.trim();
    final savingsGoal = _savingsGoalController.text.trim();
    if (incomeSource.isEmpty ||
        incomeFrequency.isEmpty ||
        biggestProblem.isEmpty ||
        amountKobo == null ||
        amountKobo <= 0) {
      setState(() {
        _error = 'Add your income source, rhythm, balance, and money problem.';
      });
      return;
    }

    final answers = OnboardingAnswers(
      incomeSource: incomeSource,
      incomeFrequency: incomeFrequency,
      currentBalanceKobo: amountKobo,
      biggestProblem: biggestProblem,
      savingsGoal: savingsGoal.isEmpty ? null : savingsGoal,
    );

    setState(() => _submitting = true);
    try {
      final budget = await ref
          .read(koloRepositoryProvider)
          .generateBudget(answers);
      if (!mounted) return;
      setState(() {
        _previewAnswers = answers;
        _previewBudget = budget;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _acceptBudget() async {
    final answers = _previewAnswers;
    if (answers == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(koloRepositoryProvider)
          .completeOnboarding(answers, budget: _previewBudget);
      if (!mounted) return;
      GoRouter.maybeOf(context)?.go('/biometric-setup');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _clearPreview() {
    setState(() {
      _previewBudget = null;
      _previewAnswers = null;
      _error = null;
    });
  }

  String get _buttonLabel {
    if (_submitting) return 'Building';
    if (_step == 0) return 'Start setup';
    if (_step < _stepCount - 1) return 'Next';
    return 'Preview budget';
  }

  String get _assistantText {
    return switch (_step) {
      0 =>
        "Hey! I'm Kolo, your personal money manager. Before we start, let me understand your situation.",
      1 => 'How do you usually get money?',
      2 => 'Is that money regular, or does it come when it comes?',
      3 =>
        "What's your balance right now across all your accounts? An estimate is fine.",
      4 => "What's your biggest money problem right now?",
      _ => 'Is there something specific you are saving towards?',
    };
  }

  String get _stepTitle {
    return switch (_step) {
      0 => 'Meet Kolo',
      1 => 'Income source',
      2 => 'Income rhythm',
      3 => 'Current balance',
      4 => 'Main money problem',
      _ => 'Savings goal',
    };
  }

  String get _stepSubtitle {
    return switch (_step) {
      0 => 'A short setup chat helps Kolo build advice around your real life.',
      1 => 'Tell Kolo where money usually comes from.',
      2 => 'Use your own words if none of the chips fit.',
      3 => 'Your balance helps Kolo size the first budget.',
      4 => 'This becomes the thing Kolo watches closely.',
      _ => 'Optional, but Kolo can protect this money in future decisions.',
    };
  }

  String get _previousAnswer {
    final answer = switch (_step) {
      1 => 'Ready',
      2 => _incomeController.text.trim(),
      3 => _frequencyController.text.trim(),
      4 =>
        _balanceController.text.trim().isEmpty
            ? ''
            : 'NGN ${_balanceController.text.trim()}',
      5 => _problemController.text.trim(),
      _ => '',
    };
    return answer.isEmpty ? 'Noted' : answer;
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.currentStep, required this.count});

  final int currentStep;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            key: Key('onboarding_progress_dot_$index'),
            duration: const Duration(milliseconds: 200),
            height: 8,
            width: index == currentStep ? 24 : 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: index == currentStep
                  ? KoloColors.primary
                  : Colors.white.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({
    required this.assistantText,
    required this.previousAnswer,
    required this.showPreviousAnswer,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.error,
    required this.submitting,
    required this.buttonLabel,
    required this.onNext,
  });

  final String assistantText;
  final String previousAnswer;
  final bool showPreviousAnswer;
  final String title;
  final String subtitle;
  final Widget content;
  final String? error;
  final bool submitting;
  final String buttonLabel;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AssistantBubble(text: assistantText),
        if (showPreviousAnswer) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _UserReplyPreview(text: previousAnswer),
          ),
        ],
        const SizedBox(height: 20),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: KoloColors.textSecondary)),
        const SizedBox(height: 20),
        Expanded(child: content),
        if (error != null) ...[
          Text(error!, style: const TextStyle(color: KoloColors.expense)),
          const SizedBox(height: 10),
        ],
        ElevatedButton(
          key: const Key('onboarding_next'),
          onPressed: submitting ? null : onNext,
          child: Text(buttonLabel),
        ),
      ],
    );
  }
}

class _OnboardingBudgetPreview extends StatelessWidget {
  const _OnboardingBudgetPreview({
    required this.budget,
    required this.saving,
    required this.error,
    required this.onAccept,
    required this.onBack,
  });

  final BudgetPlan budget;
  final bool saving;
  final String? error;
  final VoidCallback onAccept;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('onboarding_budget_preview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AssistantBubble(
          text:
              "I've drafted your first budget. Check the split, then we can turn on the sensors that keep it updated.",
        ),
        const SizedBox(height: 18),
        Text(
          'Preview my first budget',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Monthly income estimate: ${MoneyFormatter.formatKobo(budget.monthlyIncomeKobo)}',
          style: const TextStyle(color: KoloColors.textSecondary),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _BudgetPreviewSummary(budget: budget),
                const SizedBox(height: 12),
                for (final category in budget.categories) ...[
                  _BudgetPreviewCategoryRow(category: category),
                  const SizedBox(height: 10),
                ],
                if (budget.aiNotes.trim().isNotEmpty)
                  _BudgetPreviewNote(note: budget.aiNotes),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: const TextStyle(color: KoloColors.expense)),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('onboarding_edit_budget_inputs'),
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Change answers'),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          key: const Key('onboarding_accept_budget'),
          onPressed: saving ? null : onAccept,
          icon: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(saving ? 'Saving' : 'Use this budget'),
        ),
      ],
    );
  }
}

class _BudgetPreviewSummary extends StatelessWidget {
  const _BudgetPreviewSummary({required this.budget});

  final BudgetPlan budget;

  @override
  Widget build(BuildContext context) {
    final unallocatedKobo =
        budget.monthlyIncomeKobo - budget.totalAllocatedKobo;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KoloColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _BudgetPreviewStat(
              label: 'Allocated',
              amount: MoneyFormatter.formatKobo(budget.totalAllocatedKobo),
            ),
          ),
          Container(width: 1, height: 42, color: const Color(0xFFE9D5FF)),
          Expanded(
            child: _BudgetPreviewStat(
              label: unallocatedKobo >= 0 ? 'Left loose' : 'Over plan',
              amount: MoneyFormatter.formatKobo(unallocatedKobo),
              color: unallocatedKobo >= 0
                  ? KoloColors.income
                  : KoloColors.expense,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetPreviewStat extends StatelessWidget {
  const _BudgetPreviewStat({
    required this.label,
    required this.amount,
    this.color = KoloColors.textPrimary,
  });

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: KoloColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: TextStyle(
                color: color,
                fontFamily: 'DM Mono',
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetPreviewCategoryRow extends StatelessWidget {
  const _BudgetPreviewCategoryRow({required this.category});

  final BudgetCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KoloColors.surfaceWhite,
        border: Border.all(color: const Color(0xFFEDE9FE)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: KoloColors.primaryPastel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_categoryIcon, color: KoloColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            MoneyFormatter.formatKobo(category.allocatedKobo),
            style: const TextStyle(
              color: KoloColors.textPrimary,
              fontFamily: 'DM Mono',
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  IconData get _categoryIcon {
    final value = '${category.name} ${category.emoji}'.toLowerCase();
    if (value.contains('food')) return Icons.restaurant_outlined;
    if (value.contains('save') || value.contains('safe')) {
      return Icons.lock_outline;
    }
    if (value.contains('transport')) return Icons.directions_bus_outlined;
    if (value.contains('bill')) return Icons.receipt_long_outlined;
    return Icons.pie_chart_outline;
  }
}

class _BudgetPreviewNote extends StatelessWidget {
  const _BudgetPreviewNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KoloColors.primaryPastel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        note,
        style: const TextStyle(
          color: KoloColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UserReplyPreview extends StatelessWidget {
  const _UserReplyPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: KoloColors.primary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 14,
          backgroundColor: KoloColors.primary,
          child: Icon(Icons.auto_awesome, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: KoloColors.surfaceElevated,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Text(text),
          ),
        ),
      ],
    );
  }
}

class _FreeTextStep extends StatelessWidget {
  const _FreeTextStep({
    required this.fieldKey,
    required this.controller,
    required this.labelText,
    required this.icon,
    required this.suggestions,
    required this.onSuggestion,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String labelText;
  final IconData icon;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        TextField(
          key: fieldKey,
          controller: controller,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: labelText,
            prefixIcon: Icon(icon),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final label in suggestions)
              _ChoicePill(
                key: Key(
                  '${(fieldKey as ValueKey<String>).value}_${_keySlug(label)}',
                ),
                label: label,
                selected: controller.text == label,
                onTap: () => onSuggestion(label),
              ),
          ],
        ),
      ],
    );
  }

  String _keySlug(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'(^_|_$)'), '');
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? KoloColors.primary : KoloColors.primaryPastel,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : KoloColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PermissionSetupPanel extends ConsumerStatefulWidget {
  const _PermissionSetupPanel();

  @override
  ConsumerState<_PermissionSetupPanel> createState() =>
      _PermissionSetupPanelState();
}

class _PermissionSetupPanelState extends ConsumerState<_PermissionSetupPanel> {
  final Set<KoloPermission> _granted = {};

  @override
  Widget build(BuildContext context) {
    final permissions = const [
      _PermissionSpec(
        permission: KoloPermission.sms,
        icon: Icons.sms_outlined,
        title: 'SMS monitoring',
        body: 'Reads bank alerts so Kolo can detect transactions.',
      ),
      _PermissionSpec(
        permission: KoloPermission.notifications,
        icon: Icons.notifications_none,
        title: 'Notifications',
        body: 'Watches fintech alerts when SMS is missing.',
      ),
      _PermissionSpec(
        permission: KoloPermission.overlay,
        icon: Icons.bubble_chart_outlined,
        title: 'Floating Kolo bubble',
        body: 'Shows quick guidance while you are inside money apps.',
      ),
      _PermissionSpec(
        permission: KoloPermission.accessibility,
        icon: Icons.visibility_outlined,
        title: 'Watched app detection',
        body: 'Lets Kolo notice when selected finance apps are opened.',
      ),
      _PermissionSpec(
        permission: KoloPermission.backgroundService,
        icon: Icons.sync_outlined,
        title: 'Background service',
        body: 'Keeps reminders, parsing, and retry sync alive.',
      ),
    ];

    return KoloGradientScaffold(
      title: 'Permissions',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: Column(
          children: [
            KoloCard(
              color: KoloColors.surfaceDark,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Android-first money awareness',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Sora',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Turn on only what you want. Locked states stay visible so Kolo never pretends it can see what it cannot.',
                    style: TextStyle(color: KoloColors.textOnDarkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (final permission in permissions)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PermissionSetupTile(
                  spec: permission,
                  granted: _granted.contains(permission.permission),
                  onGrant: () async {
                    final state = await ref
                        .read(permissionRequesterProvider)
                        .request(permission.permission);
                    await ref
                        .read(koloRepositoryProvider)
                        .updatePermission(permission.permission, state);
                    if (!mounted) return;
                    if (state == PermissionGrantState.granted) {
                      setState(() => _granted.add(permission.permission));
                    }
                  },
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => GoRouter.maybeOf(context)?.go('/home'),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionSpec {
  const _PermissionSpec({
    required this.permission,
    required this.icon,
    required this.title,
    required this.body,
  });

  final KoloPermission permission;
  final IconData icon;
  final String title;
  final String body;

  String get keyName => 'permission_${permission.name}';
}

class _PermissionSetupTile extends StatelessWidget {
  const _PermissionSetupTile({
    required this.spec,
    required this.granted,
    required this.onGrant,
  });

  final _PermissionSpec spec;
  final bool granted;
  final Future<void> Function() onGrant;

  @override
  Widget build(BuildContext context) {
    return KoloCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        key: Key(spec.keyName),
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: KoloColors.primaryPastel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(spec.icon, color: KoloColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  spec.body,
                  style: const TextStyle(color: KoloColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            key: Key('permission_setup_${spec.permission.name}'),
            borderRadius: BorderRadius.circular(999),
            onTap: granted ? null : onGrant,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: granted
                    ? KoloColors.income.withValues(alpha: 0.12)
                    : KoloColors.primaryPastel,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                granted ? 'Granted' : 'Setup',
                key: granted
                    ? Key('permission_granted_${spec.permission.name}')
                    : null,
                style: TextStyle(
                  color: granted ? KoloColors.income : KoloColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
