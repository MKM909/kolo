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
      } else {
        await auth.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }

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
}

class _OnboardingSetupScreen extends ConsumerStatefulWidget {
  const _OnboardingSetupScreen();

  @override
  ConsumerState<_OnboardingSetupScreen> createState() =>
      _OnboardingSetupScreenState();
}

class _OnboardingSetupScreenState extends ConsumerState<_OnboardingSetupScreen> {
  final _incomeController = TextEditingController();
  final _balanceController = TextEditingController();
  int _step = 0;
  String _incomeFrequency = 'Irregular gigs';
  String _biggestProblem = 'Impulse buys';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _incomeController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KoloGradientScaffold(
      child: Column(
        children: [
          const SizedBox(height: 18),
          _ProgressDots(currentStep: _step, count: 4),
          Expanded(
            flex: 4,
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
            flex: 6,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _AssistantBubble(
                    text:
                        'Let me build your first money plan. I will ask a few quick questions and keep it practical.',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _step == 0
                        ? 'Income source'
                        : _step == 1
                        ? 'Income rhythm'
                        : _step == 2
                        ? 'Current balance'
                        : 'Main money problem',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _step == 0
                        ? 'Tell Kolo where money usually comes from.'
                        : _step == 1
                        ? 'Pick the pattern that feels closest.'
                        : _step == 2
                        ? 'Your balance helps Kolo size the first budget.'
                        : 'This becomes the thing Kolo watches closely.',
                    style: const TextStyle(color: KoloColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Expanded(child: _stepContent()),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: KoloColors.expense),
                    ),
                    const SizedBox(height: 10),
                  ],
                  ElevatedButton(
                    key: const Key('onboarding_next'),
                    onPressed: _submitting ? null : _advance,
                    child: Text(
                      _submitting
                          ? 'Building'
                          : _step < 3
                          ? 'Next'
                          : 'Build my Kolo',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepContent() {
    if (_step == 0) {
      return TextField(
        key: const Key('onboarding_income_source'),
        controller: _incomeController,
        decoration: const InputDecoration(
          labelText: 'Example: freelance design, allowance, salary',
          prefixIcon: Icon(Icons.work_outline),
        ),
      );
    }
    if (_step == 1) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final label in const [
            'Weekly',
            'Monthly',
            'Irregular gigs',
            'Family support',
          ])
            _ChoicePill(
              key: Key('onboarding_income_frequency_${_keySlug(label)}'),
              label: label,
              selected: _incomeFrequency == label,
              onTap: () => setState(() => _incomeFrequency = label),
            ),
        ],
      );
    }
    if (_step == 2) {
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final label in const [
          'Food spending',
          'Transport leaks',
          'Impulse buys',
          'Irregular income',
        ])
          _ChoicePill(
            key: Key('onboarding_problem_${_keySlug(label)}'),
            label: label,
            selected: _biggestProblem == label,
            onTap: () => setState(() => _biggestProblem = label),
          ),
      ],
    );
  }

  Future<void> _advance() async {
    setState(() => _error = null);
    if (_step < 3) {
      setState(() => _step += 1);
      return;
    }

    final amountKobo = MoneyFormatter.parseNairaToKobo(
      _balanceController.text.trim(),
    );
    final incomeSource = _incomeController.text.trim();
    if (incomeSource.isEmpty || amountKobo == null || amountKobo <= 0) {
      setState(() {
        _error = 'Add your income source and current balance.';
      });
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(koloRepositoryProvider)
          .completeOnboarding(
            OnboardingAnswers(
              incomeSource: incomeSource,
              incomeFrequency: _incomeFrequency,
              currentBalanceKobo: amountKobo,
              biggestProblem: _biggestProblem,
            ),
          );
      if (!mounted) return;
      GoRouter.maybeOf(context)?.go('/permissions');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _keySlug(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(
      RegExp(r'(^_|_$)'),
      '',
    );
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

class _PermissionSetupPanel extends StatelessWidget {
  const _PermissionSetupPanel();

  @override
  Widget build(BuildContext context) {
    final permissions = const [
      _PermissionSpec(
        keyName: 'permission_sms',
        icon: Icons.sms_outlined,
        title: 'SMS monitoring',
        body: 'Reads bank alerts so Kolo can detect transactions.',
      ),
      _PermissionSpec(
        keyName: 'permission_notifications',
        icon: Icons.notifications_none,
        title: 'Notifications',
        body: 'Watches fintech alerts when SMS is missing.',
      ),
      _PermissionSpec(
        keyName: 'permission_overlay',
        icon: Icons.bubble_chart_outlined,
        title: 'Floating Kolo bubble',
        body: 'Shows quick guidance while you are inside money apps.',
      ),
      _PermissionSpec(
        keyName: 'permission_accessibility',
        icon: Icons.visibility_outlined,
        title: 'Watched app detection',
        body: 'Lets Kolo notice when selected finance apps are opened.',
      ),
      _PermissionSpec(
        keyName: 'permission_backgroundService',
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
                child: _PermissionSetupTile(spec: permission),
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
    required this.keyName,
    required this.icon,
    required this.title,
    required this.body,
  });

  final String keyName;
  final IconData icon;
  final String title;
  final String body;
}

class _PermissionSetupTile extends StatelessWidget {
  const _PermissionSetupTile({required this.spec});

  final _PermissionSpec spec;

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: KoloColors.primaryPastel,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Setup',
              style: TextStyle(
                color: KoloColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
