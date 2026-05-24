import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kolo/app/providers.dart';
import 'package:kolo/domain/models/models.dart';
import 'package:kolo/domain/services/ai_failure_message.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/core/widgets/kolo_scaffold.dart';
import 'package:kolo/ui/core/widgets/kolo_liquid_aether_orb.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key, this.initialPrompt});

  final String? initialPrompt;

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<AiMessage> _localMessages = [];
  String? _seededPrompt;

  @override
  void initState() {
    super.initState();
    _seedPrompt();
  }

  @override
  void didUpdateWidget(covariant AiChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPrompt != widget.initialPrompt) _seedPrompt();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);

    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const _AiOfflineState(),
      data: (state) => KoloGradientScaffold(
        title: 'Kolo AI',
        child: Column(
          children: [
            Expanded(
              child: ListView(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  for (final message in _localMessages)
                    _ChatBubble(message: message),
                  for (final message in state.aiMessages)
                    _ChatBubble(message: message),
                  _PromptChip(
                    text: 'Can I afford a new pair of shoes?',
                    onTap: () =>
                        _sendMessage('Can I afford a new pair of shoes?'),
                  ),
                  _PromptChip(
                    text: 'Redo my budget, I just got a gig',
                    onTap: () =>
                        _sendMessage('Redo my budget, I just got a gig'),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 108),
              color: Colors.white.withValues(alpha: 0.88),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('kolo_ai_chat_input'),
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Ask Kolo...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: () => _sendMessage(_controller.text),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return;
    try {
      await ref.read(koloRepositoryProvider).sendAiMessage(text);
    } on Object {
      final now = DateTime.now();
      setState(() {
        _localMessages.insertAll(0, [
          AiMessage(
            id: 'local-ai-failure-${now.microsecondsSinceEpoch}',
            role: AiRole.assistant,
            content: AiFailureMessage.chat,
            timestamp: now,
            context: 'chat_failure',
          ),
          AiMessage(
            id: 'local-user-${now.microsecondsSinceEpoch}',
            role: AiRole.user,
            content: text,
            timestamp: now,
            context: 'chat_failure',
          ),
        ]);
      });
    }
    if (rawText == _controller.text) _controller.clear();
  }

  void _seedPrompt() {
    final prompt = widget.initialPrompt?.trim();
    if (prompt == null || prompt.isEmpty || prompt == _seededPrompt) return;
    _controller.text = prompt;
    _seededPrompt = prompt;
  }
}

class _AiOfflineState extends StatelessWidget {
  const _AiOfflineState();

  @override
  Widget build(BuildContext context) {
    return KoloGradientScaffold(
      title: 'Kolo AI',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: KoloCard(
            key: const Key('kolo_ai_offline_state'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                KoloLiquidAetherOrb(size: 64),
                SizedBox(height: 18),
                Text(
                  'Kolo is offline',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: KoloColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'I can still show saved chats and balance once local data is available. Gemini replies will resume when the connection returns.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: KoloColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AiRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              const KoloLiquidAetherOrb(
                key: Key('kolo_ai_chat_avatar'),
                size: 28,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 310),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isUser ? KoloColors.primary : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x10000000), blurRadius: 12),
                  ],
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isUser ? Colors.white : KoloColors.textPrimary,
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

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: KoloColors.primaryPastel,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              text,
              style: const TextStyle(color: KoloColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}
