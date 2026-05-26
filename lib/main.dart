import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kolo/app/kolo_app.dart';
import 'package:kolo/data/services/hive_dashboard_cache_store.dart';
import 'package:kolo/data/services/firebase_bootstrap.dart';
import 'package:kolo/data/services/kolo_background_service.dart';
import 'package:kolo/data/services/offline_sync_queue.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/core/widgets/kolo_liquid_aether_orb.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox<Object?>(koloDashboardCacheBoxName),
    Hive.openBox<Object?>(koloOfflineSyncBoxName),
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
  const KoloOverlayBubble({super.key});

  @override
  State<KoloOverlayBubble> createState() => _KoloOverlayBubbleState();
}

class _KoloOverlayBubbleState extends State<KoloOverlayBubble> {
  final TextEditingController _controller = TextEditingController();
  final List<_OverlayChatMessage> _messages = [
    const _OverlayChatMessage.assistant(
      'Hello. I can talk through a spend, log a note, or help you pause before money leaves.',
    ),
  ];
  StreamSubscription<Object?>? _overlaySubscription;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _overlaySubscription = FlutterOverlayWindow.overlayListener.listen(
      _handleOverlayMessage,
    );
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
    _controller.clear();
    setState(() {
      _messages.add(_OverlayChatMessage.user(text));
      _messages.add(_OverlayChatMessage.assistant(_replyFor(text)));
    });
    try {
      await FlutterOverlayWindow.shareData({
        'type': 'userMessage',
        'text': text,
      });
    } on Object {
      // The overlay remains usable even when the platform channel is absent.
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

class _OverlayChatMessage {
  const _OverlayChatMessage.assistant(this.text) : isUser = false;

  const _OverlayChatMessage.user(this.text) : isUser = true;

  final String text;
  final bool isUser;
}
