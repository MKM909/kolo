import 'package:flutter/material.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';

class KoloGradientScaffold extends StatelessWidget {
  const KoloGradientScaffold({
    required this.child,
    this.title,
    this.actions = const [],
    super.key,
  });

  final Widget child;
  final String? title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KoloColors.backgroundStart, KoloColors.backgroundEnd],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: title == null && actions.isEmpty
            ? null
            : AppBar(
                toolbarHeight: 60,
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: title == null ? null : Text(title!),
                actions: actions,
              ),
        body: SafeArea(child: child),
      ),
    );
  }
}

class KoloCard extends StatelessWidget {
  const KoloCard({
    required this.child,
    this.padding = const EdgeInsets.all(KoloSpacing.xl),
    this.color = Colors.white,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class KoloSectionHeader extends StatelessWidget {
  const KoloSectionHeader({required this.title, this.action, super.key});

  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KoloSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (action != null)
            Text(
              action!,
              style: const TextStyle(
                color: KoloColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
