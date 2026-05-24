import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/money_formatter.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';

class KoloFloatingAssistant extends ConsumerStatefulWidget {
  const KoloFloatingAssistant({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  ConsumerState<KoloFloatingAssistant> createState() =>
      _KoloFloatingAssistantState();
}

class _KoloFloatingAssistantState extends ConsumerState<KoloFloatingAssistant> {
  final TextEditingController _controller = TextEditingController();
  bool _expanded = false;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(koloRepositoryProvider).sendAiMessage(text);
      _controller.clear();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_expanded) {
      return _FloatingConversationPanel(
        controller: _controller,
        sending: _sending,
        onClose: () => setState(() => _expanded = false),
        onSend: _sendMessage,
      );
    }

    return Align(
      key: const Key('kolo_floating_assistant'),
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 18, bottom: 108),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 178),
              margin: const EdgeInsets.only(right: 10, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: KoloColors.surfaceDark.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(5),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Text(
                'Need a quick money check?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                widget.onTap?.call();
                setState(() => _expanded = true);
              },
              child: const _LiquidAetherOrb(includeTestKey: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingConversationPanel extends ConsumerWidget {
  const _FloatingConversationPanel({
    required this.controller,
    required this.sending,
    required this.onClose,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onClose;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    return Align(
      key: const Key('kolo_floating_assistant'),
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 14, bottom: 94, left: 14),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340, maxHeight: 430),
            child: Container(
              key: const Key('kolo_floating_conversation'),
              decoration: BoxDecoration(
                color: const Color(0xF0FFFFFF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 40,
                    offset: Offset(0, -4),
                  ),
                  BoxShadow(
                    color: Color(0x337C3AED),
                    blurRadius: 28,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
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
                    dashboard.when(
                      loading: () => const _FloatingHeader(
                        balanceLabel: 'Loading...',
                        onClose: null,
                      ),
                      error: (_, _) => const _FloatingHeader(
                        balanceLabel: 'Offline',
                        onClose: null,
                      ),
                      data: (state) => _FloatingHeader(
                        balanceLabel: MoneyFormatter.formatKobo(
                          state.balanceKobo,
                        ),
                        onClose: onClose,
                      ),
                    ),
                    Expanded(
                      child: dashboard.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (error, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Kolo cannot load chats right now.',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        data: (state) =>
                            _FloatingMessageList(messages: state.aiMessages),
                      ),
                    ),
                    _FloatingInput(
                      controller: controller,
                      sending: sending,
                      onSend: onSend,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingHeader extends StatelessWidget {
  const _FloatingHeader({required this.balanceLabel, required this.onClose});

  final String balanceLabel;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
      child: Row(
        children: [
          const SizedBox(height: 36, width: 36, child: _LiquidAetherOrb()),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ask Kolo from anywhere',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Quick money checks and calm nudges.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KoloColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: KoloColors.primaryPastel,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              balanceLabel,
              style: const TextStyle(
                color: KoloColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close Kolo',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _FloatingMessageList extends StatelessWidget {
  const _FloatingMessageList({required this.messages});

  final List<AiMessage> messages;

  @override
  Widget build(BuildContext context) {
    final visibleMessages = messages.take(6).toList();
    return SingleChildScrollView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Column(
        children: [
          if (visibleMessages.isEmpty)
            const _FloatingStarterMessage()
          else
            for (final message in visibleMessages)
              _FloatingChatBubble(message: message),
        ],
      ),
    );
  }
}

class _FloatingStarterMessage extends StatelessWidget {
  const _FloatingStarterMessage();

  @override
  Widget build(BuildContext context) {
    return const _AssistantBubbleShell(
      child: Text(
        'Hello. I can check your balance, explain a spend, or help you decide before you buy.',
        style: TextStyle(color: KoloColors.textPrimary, fontSize: 13),
      ),
    );
  }
}

class _FloatingChatBubble extends StatelessWidget {
  const _FloatingChatBubble({required this.message});

  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AiRole.user;
    if (!isUser) {
      return _AssistantBubbleShell(
        child: Text(
          message.content,
          style: const TextStyle(color: KoloColors.textPrimary, fontSize: 13),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 248),
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
          boxShadow: [
            BoxShadow(
              color: Color(0x247C3AED),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          message.content,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}

class _AssistantBubbleShell extends StatelessWidget {
  const _AssistantBubbleShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, right: 28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 28, width: 28, child: _LiquidAetherOrb()),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 248),
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
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingInput extends StatelessWidget {
  const _FloatingInput({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        border: const Border(top: BorderSide(color: Color(0xFFEDE9FE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('kolo_floating_input'),
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
            key: const Key('kolo_floating_send'),
            tooltip: 'Send to Kolo',
            onPressed: sending ? null : onSend,
            style: IconButton.styleFrom(
              backgroundColor: KoloColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: KoloColors.primary.withValues(
                alpha: 0.45,
              ),
            ),
            icon: sending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _LiquidAetherOrb extends StatelessWidget {
  const _LiquidAetherOrb({this.includeTestKey = false});

  final bool includeTestKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: includeTestKey ? const Key('kolo_liquid_aether_orb') : null,
      height: 58,
      width: 58,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x557C3AED),
            blurRadius: 24,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: CustomPaint(
          painter: _LiquidAetherPainter(),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _LiquidAetherPainter extends CustomPainter {
  const _LiquidAetherPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width * 0.58, size.height * 0.48);
    final radius = size.shortestSide / 2;

    final base = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.28, -0.32),
        radius: 0.92,
        colors: const [
          Color(0xFF111827),
          Color(0xFF111827),
          Color(0xFF3347FF),
          Color(0xFF7C3AED),
          Color(0xFF050816),
        ],
        stops: const [0, 0.35, 0.62, 0.78, 1],
      ).createShader(rect);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, base);

    final liquid = Path()..moveTo(0, size.height * 0.66);
    for (var x = 0.0; x <= size.width; x += 4) {
      final y =
          size.height * 0.66 +
          math.sin((x / size.width * math.pi * 2.2) + 0.6) * 5;
      liquid.lineTo(x, y);
    }
    liquid
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      liquid,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF38BDF8), Color(0xFF7C3AED), Color(0xFF020617)],
        ).createShader(rect),
    );

    final glint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.42, -0.44),
        radius: 0.35,
        colors: [
          Colors.white.withValues(alpha: 0.65),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawCircle(center.translate(-18, -16), 17, glint);

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidAetherPainter oldDelegate) => false;
}
