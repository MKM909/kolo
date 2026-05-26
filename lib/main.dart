import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kolo/app/kolo_app.dart';
import 'package:kolo/data/services/hive_dashboard_cache_store.dart';
import 'package:kolo/data/services/firebase_bootstrap.dart';
import 'package:kolo/data/services/kolo_background_service.dart';
import 'package:kolo/data/services/offline_sync_queue.dart';
import 'package:kolo/data/services/reminder_sync_service.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/core/widgets/kolo_liquid_aether_orb.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox<Object?>(koloDashboardCacheBoxName),
    Hive.openBox<Object?>(koloOfflineSyncBoxName),
    Hive.openBox<Object?>(koloReminderScheduleBoxName),
  ]);
  await KoloBackgroundServiceController().configure();
  final firebaseBootstrapResult = await FirebaseBootstrap.tryInitialize();
  runApp(KoloApp(firebaseBootstrapResult: firebaseBootstrapResult));
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: KoloOverlayBubble(),
    ),
  );
}

class KoloOverlayBubble extends StatefulWidget {
  const KoloOverlayBubble({
    super.key,
    this.initialOverlayData,
    this.overlayMessages,
  });

  final Map<String, Object?>? initialOverlayData;
  final Stream<Object?>? overlayMessages;

  @override
  State<KoloOverlayBubble> createState() => _KoloOverlayBubbleState();
}

class _KoloOverlayBubbleState extends State<KoloOverlayBubble> {
  static final Stream<Object?> _overlayMessages = FlutterOverlayWindow
      .overlayListener
      .asBroadcastStream();

  final TextEditingController _controller = TextEditingController();
  final List<_OverlayChatMessage> _messages = [
    const _OverlayChatMessage.assistant(
      'Hello. I can talk through a spend, log a note, or help you pause before money leaves.',
    ),
  ];
  StreamSubscription<Object?>? _overlaySubscription;
  _OverlayBlockContext? _blockContext;
  _OverlayBlockDecision? _blockDecision;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _overlaySubscription = (widget.overlayMessages ?? _overlayMessages).listen(
      _handleOverlayMessage,
    );
    _handleOverlayMessage(widget.initialOverlayData);
  }

  @override
  void dispose() {
    _overlaySubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleOverlayMessage(Object? message) {
    if (message is! Map) return;
    final type = message['type']?.toString();
    if (type == 'blockOverlay') {
      final blockContext = _OverlayBlockContext.fromMap(message);
      if (blockContext == null) return;
      setState(() {
        _blockContext = blockContext;
        _blockDecision = null;
        _expanded = false;
        _messages
          ..clear()
          ..add(_OverlayChatMessage.assistant(blockContext.prompt));
      });
      return;
    }

    if (type == 'blockDecision') {
      final decision = _OverlayBlockDecision.fromMap(message);
      if (decision == null) return;
      setState(() {
        _blockDecision = decision;
        if (decision.message.isNotEmpty &&
            (_messages.isEmpty || _messages.last.text != decision.message)) {
          _messages.add(_OverlayChatMessage.assistant(decision.message));
        }
      });
      return;
    }

    final prompt = message['text']?.toString().trim();
    if (prompt == null || prompt.isEmpty) return;
    if (type == 'assistantMessage') {
      setState(() {
        _messages.add(_OverlayChatMessage.assistant(prompt));
      });
      if (!_expanded) {
        _setExpanded(true);
      }
      return;
    }
    if (type != 'prompt') return;
    _controller.text = prompt;
    _controller.selection = TextSelection.collapsed(offset: prompt.length);
    if (!_expanded) {
      _setExpanded(true);
    }
  }

  Future<void> _setExpanded(bool expanded) async {
    if (mounted) {
      setState(() => _expanded = expanded);
    }
    try {
      await FlutterOverlayWindow.resizeOverlay(
        expanded ? WindowSize.matchParent : 278,
        expanded ? 540 : 116,
        !expanded,
      );
      await FlutterOverlayWindow.shareData({
        'type': expanded ? 'expanded' : 'collapsed',
      });
    } on Object {
      // Tests and unsupported platforms do not have the Android overlay channel.
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final blockContext = _blockContext;
    _controller.clear();
    setState(() {
      _messages.add(_OverlayChatMessage.user(text));
      _messages.add(_OverlayChatMessage.assistant(_replyFor(text)));
    });
    try {
      await FlutterOverlayWindow.shareData({
        'type': 'userMessage',
        'text': text,
        if (blockContext != null) ...{
          'packageName': blockContext.packageName,
          'appName': blockContext.appName,
          'blockLevel': blockContext.blockLevel,
        },
      });
    } on Object {
      // The overlay remains usable even when the platform channel is absent.
    }
  }

  Future<void> _cancelBlockOverlay() async {
    final blockContext = _blockContext;
    if (mounted) {
      setState(() => _blockContext = null);
    }
    try {
      await FlutterOverlayWindow.shareData({
        'type': 'blockCancelled',
        if (blockContext != null) ...{
          'packageName': blockContext.packageName,
          'appName': blockContext.appName,
          'blockLevel': blockContext.blockLevel,
        },
      });
      await FlutterOverlayWindow.closeOverlay();
    } on Object {
      // Tests and unsupported platforms do not have the Android overlay channel.
    }
  }

  Future<void> _proceedFromBlockOverlay() async {
    final blockContext = _blockContext;
    final blockDecision = _blockDecision;
    if (mounted) {
      setState(() => _blockContext = null);
    }
    try {
      await FlutterOverlayWindow.shareData({
        'type': 'blockProceed',
        if (blockContext != null) ...{
          'packageName': blockContext.packageName,
          'appName': blockContext.appName,
          'blockLevel': blockContext.blockLevel,
        },
        if (blockDecision != null) 'status': blockDecision.status,
      });
      await FlutterOverlayWindow.closeOverlay();
    } on Object {
      // Tests and unsupported platforms do not have the Android overlay channel.
    }
  }

  String _replyFor(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('spend') ||
        lower.contains('send') ||
        lower.contains('buy')) {
      return 'I can help you pressure-test it. Tell me the amount, what it is for, and whether it protects something important.';
    }
    if (lower.contains('log')) {
      return 'Tell me the amount and category. I will keep the note ready for Kolo when you return to the app.';
    }
    return 'I am listening. Give me the money move in one sentence and I will help you think it through.';
  }

  @override
  Widget build(BuildContext context) {
    final blockContext = _blockContext;
    if (blockContext != null) {
      return _BlockOverlay(
        contextData: blockContext,
        decision: _blockDecision,
        controller: _controller,
        messages: _messages,
        onCancel: _cancelBlockOverlay,
        onProceed: _proceedFromBlockOverlay,
        onSend: _sendMessage,
      );
    }

    if (_expanded) {
      return _OverlayConversationPanel(
        controller: _controller,
        messages: _messages,
        onClose: () => _setExpanded(false),
        onQuickPrompt: (prompt) {
          _controller.text = prompt;
          _controller.selection = TextSelection.collapsed(
            offset: prompt.length,
          );
        },
        onSend: _sendMessage,
      );
    }

    return Material(
      color: Colors.transparent,
      child: Align(
        key: const Key('kolo_overlay_idle'),
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                key: const Key('kolo_overlay_speech_bubble'),
                constraints: const BoxConstraints(maxWidth: 174),
                margin: const EdgeInsets.only(right: 8, bottom: 7),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: const BoxDecoration(
                  color: KoloColors.surfaceDark,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text(
                  'Kolo is here. Want to talk before you spend?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                key: const Key('kolo_overlay_orb'),
                onTap: () => _setExpanded(true),
                child: const Stack(
                  clipBehavior: Clip.none,
                  children: [
                    KoloLiquidAetherOrb(size: 58),
                    Positioned(right: 2, top: 2, child: _OverlayAlertBadge()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockOverlay extends StatelessWidget {
  const _BlockOverlay({
    required this.contextData,
    required this.decision,
    required this.controller,
    required this.messages,
    required this.onCancel,
    required this.onProceed,
    required this.onSend,
  });

  final _OverlayBlockContext contextData;
  final _OverlayBlockDecision? decision;
  final TextEditingController controller;
  final List<_OverlayChatMessage> messages;
  final VoidCallback onCancel;
  final VoidCallback onProceed;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('kolo_block_overlay'),
      color: Colors.transparent,
      child: Stack(
        children: [
          const Positioned.fill(child: _AetherBackground()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.sizeOf(context).height * 0.17,
            left: 0,
            right: 0,
            child: const Center(
              child: KoloLiquidAetherOrb(key: Key('kolo_block_orb'), size: 82),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BlockChatPanel(
              contextData: contextData,
              decision: decision,
              controller: controller,
              messages: messages,
              onCancel: onCancel,
              onProceed: onProceed,
              onSend: onSend,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockChatPanel extends StatelessWidget {
  const _BlockChatPanel({
    required this.contextData,
    required this.decision,
    required this.controller,
    required this.messages,
    required this.onCancel,
    required this.onProceed,
    required this.onSend,
  });

  final _OverlayBlockContext contextData;
  final _OverlayBlockDecision? decision;
  final TextEditingController controller;
  final List<_OverlayChatMessage> messages;
  final VoidCallback onCancel;
  final VoidCallback onProceed;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final panelHeight = MediaQuery.sizeOf(context).height * 0.62;
    return Container(
      height: panelHeight,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xF5FFFFFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 40,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Text(
                    'Kolo',
                    style: TextStyle(
                      color: KoloColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: KoloColors.primaryPastel,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      contextData.blockLevelLabel,
                      style: const TextStyle(
                        color: KoloColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'You are opening ${contextData.appName}',
                  style: const TextStyle(
                    color: KoloColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Column(
                  children: [
                    for (final message in messages)
                      _OverlayChatBubble(message: message),
                  ],
                ),
              ),
            ),
            if (decision != null)
              _BlockDecisionActions(
                appName: contextData.appName,
                decision: decision!,
                onCancel: onCancel,
                onProceed: onProceed,
              ),
            _BlockOverlayInput(controller: controller, onSend: onSend),
            TextButton(
              key: const Key('kolo_block_cancel'),
              onPressed: onCancel,
              child: const Text(
                'Never mind, go back',
                style: TextStyle(color: KoloColors.textMuted),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

const _advisedAgainstOverridePhrase = 'I understand, let me in';

class _BlockDecisionActions extends StatefulWidget {
  const _BlockDecisionActions({
    required this.appName,
    required this.decision,
    required this.onCancel,
    required this.onProceed,
  });

  final String appName;
  final _OverlayBlockDecision decision;
  final VoidCallback onCancel;
  final VoidCallback onProceed;

  @override
  State<_BlockDecisionActions> createState() => _BlockDecisionActionsState();
}

class _BlockDecisionActionsState extends State<_BlockDecisionActions> {
  final _overrideController = TextEditingController();

  bool get _overrideConfirmed =>
      _overrideController.text.trim() == _advisedAgainstOverridePhrase;

  @override
  void didUpdateWidget(covariant _BlockDecisionActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.decision.status != widget.decision.status) {
      _overrideController.clear();
    }
  }

  @override
  void dispose() {
    _overrideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (key, label) = switch (widget.decision.status) {
      'approved' => (
        const Key('kolo_block_continue'),
        'Continue to ${widget.appName}',
      ),
      'caution' => (const Key('kolo_block_proceed_anyway'), 'Proceed anyway'),
      'advisedAgainst' => (
        const Key('kolo_block_confirm_override'),
        'Let me in',
      ),
      _ => (const Key('kolo_block_continue'), 'Continue'),
    };

    final isAdvisedAgainst = widget.decision.status == 'advisedAgainst';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        border: const Border(top: BorderSide(color: Color(0xFFEDE9FE))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isAdvisedAgainst) ...[
            const Text(
              'Type "$_advisedAgainstOverridePhrase" to override.',
              style: TextStyle(
                color: KoloColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('kolo_block_override_confirmation'),
              controller: _overrideController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: _advisedAgainstOverridePhrase,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: key,
                  onPressed: isAdvisedAgainst && !_overrideConfirmed
                      ? null
                      : widget.onProceed,
                  child: Text(label),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                key: const Key('kolo_block_go_back'),
                onPressed: widget.onCancel,
                child: const Text('Go back'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BlockOverlayInput extends StatelessWidget {
  const _BlockOverlayInput({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        border: const Border(top: BorderSide(color: Color(0xFFEDE9FE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('kolo_block_input'),
              controller: controller,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: "Tell Kolo what's up...",
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            key: const Key('kolo_block_send'),
            tooltip: 'Send to Kolo',
            onPressed: onSend,
            style: IconButton.styleFrom(
              backgroundColor: KoloColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _AetherBackground extends StatefulWidget {
  const _AetherBackground();

  @override
  State<_AetherBackground> createState() => _AetherBackgroundState();
}

class _AetherBackgroundState extends State<_AetherBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: const Key('kolo_aether_background'),
      painter: _AetherPainter(_controller),
    );
  }
}

class _AetherPainter extends CustomPainter {
  const _AetherPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = KoloColors.scaffold);
    final t = animation.value * math.pi * 2;
    _drawOrb(
      canvas,
      size,
      center: Offset(
        size.width * (0.28 + math.sin(t) * 0.10),
        size.height * (0.32 + math.cos(t * 0.8) * 0.08),
      ),
      radius: size.shortestSide * 0.72,
      color: KoloColors.backgroundStart.withValues(alpha: 0.68),
    );
    _drawOrb(
      canvas,
      size,
      center: Offset(
        size.width * (0.74 + math.sin(t * 0.7 + 1.8) * 0.12),
        size.height * (0.26 + math.cos(t * 0.9 + 1.4) * 0.11),
      ),
      radius: size.shortestSide * 0.62,
      color: KoloColors.backgroundEnd.withValues(alpha: 0.58),
    );
    _drawOrb(
      canvas,
      size,
      center: Offset(
        size.width * (0.58 + math.sin(t * 1.1 + 3.1) * 0.14),
        size.height * (0.62 + math.cos(t * 0.6 + 2.2) * 0.10),
      ),
      radius: size.shortestSide * 0.52,
      color: KoloColors.primaryLight.withValues(alpha: 0.34),
    );
  }

  void _drawOrb(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _AetherPainter oldDelegate) => false;
}

class _OverlayConversationPanel extends StatelessWidget {
  const _OverlayConversationPanel({
    required this.controller,
    required this.messages,
    required this.onClose,
    required this.onQuickPrompt,
    required this.onSend,
  });

  final TextEditingController controller;
  final List<_OverlayChatMessage> messages;
  final VoidCallback onClose;
  final ValueChanged<String> onQuickPrompt;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final panelHeight = MediaQuery.sizeOf(context).height * 0.60;
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          key: const Key('kolo_overlay_conversation'),
          height: panelHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xF0FFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x20000000),
                blurRadius: 40,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      const KoloLiquidAetherOrb(size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Kolo',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: KoloColors.primaryPastel,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Balance synced in app',
                          style: TextStyle(
                            color: KoloColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('kolo_overlay_close'),
                        tooltip: 'Collapse Kolo',
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: Column(
                      children: [
                        for (final message in messages)
                          _OverlayChatBubble(message: message),
                      ],
                    ),
                  ),
                ),
                _OverlayQuickActions(onQuickPrompt: onQuickPrompt),
                _OverlayInput(controller: controller, onSend: onSend),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayQuickActions extends StatelessWidget {
  const _OverlayQuickActions({required this.onQuickPrompt});

  final ValueChanged<String> onQuickPrompt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.66),
        border: const Border(top: BorderSide(color: Color(0xFFEDE9FE))),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _OverlayQuickActionButton(
            icon: Icons.psychology_alt_outlined,
            label: 'Check spend',
            onPressed: () => onQuickPrompt('Can I spend this?'),
          ),
          _OverlayQuickActionButton(
            icon: Icons.add_circle_outline,
            label: 'Log note',
            onPressed: () => onQuickPrompt('Help me log this.'),
          ),
          _OverlayQuickActionButton(
            icon: Icons.pause_circle_outline,
            label: 'Pause me',
            onPressed: () => onQuickPrompt('Help me pause before spending.'),
          ),
        ],
      ),
    );
  }
}

class _OverlayQuickActionButton extends StatelessWidget {
  const _OverlayQuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        foregroundColor: KoloColors.primary,
        side: const BorderSide(color: Color(0xFFEDE9FE)),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _OverlayInput extends StatelessWidget {
  const _OverlayInput({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        border: const Border(top: BorderSide(color: Color(0xFFEDE9FE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('kolo_overlay_input'),
              controller: controller,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Ask Kolo...',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            key: const Key('kolo_overlay_send'),
            tooltip: 'Send to Kolo',
            onPressed: onSend,
            style: IconButton.styleFrom(
              backgroundColor: KoloColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _OverlayChatBubble extends StatelessWidget {
  const _OverlayChatBubble({required this.message});

  final _OverlayChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          margin: const EdgeInsets.only(bottom: 10, left: 42),
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
            message.text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, right: 28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            const KoloLiquidAetherOrb(size: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 260),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(color: Color(0x12000000), blurRadius: 14),
                  ],
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(
                    color: KoloColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayAlertBadge extends StatelessWidget {
  const _OverlayAlertBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KoloColors.expense,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const SizedBox.square(dimension: 12),
    );
  }
}

class _OverlayBlockContext {
  const _OverlayBlockContext({
    required this.appName,
    required this.packageName,
    required this.blockLevel,
    required this.prompt,
  });

  final String appName;
  final String packageName;
  final String blockLevel;
  final String prompt;

  String get blockLevelLabel {
    return switch (blockLevel) {
      'hardLock' => 'Hard Lock',
      'explain' => 'Explain',
      _ => 'Block Mode',
    };
  }

  static _OverlayBlockContext? fromMap(Map<Object?, Object?> map) {
    final appName = map['appName']?.toString().trim();
    final packageName = map['packageName']?.toString().trim();
    final blockLevel = map['blockLevel']?.toString().trim();
    final prompt = map['prompt']?.toString().trim();
    if (appName == null ||
        appName.isEmpty ||
        packageName == null ||
        packageName.isEmpty ||
        blockLevel == null ||
        blockLevel.isEmpty) {
      return null;
    }

    return _OverlayBlockContext(
      appName: appName,
      packageName: packageName,
      blockLevel: blockLevel,
      prompt: prompt == null || prompt.isEmpty
          ? _fallbackPrompt(appName, blockLevel)
          : prompt,
    );
  }

  static String _fallbackPrompt(String appName, String blockLevel) {
    if (blockLevel == 'hardLock') {
      return 'Hold on. You are opening $appName. What is the plan?';
    }
    return 'Before you go in, what is this for?';
  }
}

class _OverlayBlockDecision {
  const _OverlayBlockDecision({required this.status, required this.message});

  final String status;
  final String message;

  static _OverlayBlockDecision? fromMap(Map<Object?, Object?> map) {
    final status = map['status']?.toString().trim();
    if (status == null || status.isEmpty) return null;
    return _OverlayBlockDecision(
      status: status,
      message: map['message']?.toString().trim() ?? '',
    );
  }
}

class _OverlayChatMessage {
  const _OverlayChatMessage.assistant(this.text) : isUser = false;

  const _OverlayChatMessage.user(this.text) : isUser = true;

  final String text;
  final bool isUser;
}
