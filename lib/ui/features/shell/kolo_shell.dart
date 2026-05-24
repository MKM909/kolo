import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kolo/ui/core/theme/kolo_theme.dart';
import 'package:kolo/ui/features/assistant/kolo_floating_assistant.dart';

class KoloShell extends StatelessWidget {
  const KoloShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          navigationShell,
          const KoloFloatingAssistant(),
        ],
      ),
      bottomNavigationBar: _KoloBottomNav(
        currentIndex: navigationShell.currentIndex,
        onSelect: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

class _KoloBottomNav extends StatelessWidget {
  const _KoloBottomNav({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 94,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
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
        child: Row(
          children: [
            _NavItem(
              index: 0,
              currentIndex: currentIndex,
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
              onSelect: onSelect,
            ),
            _NavItem(
              index: 1,
              currentIndex: currentIndex,
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long,
              label: 'Transactions',
              onSelect: onSelect,
            ),
            _AiNavItem(currentIndex: currentIndex, onSelect: onSelect),
            _NavItem(
              index: 3,
              currentIndex: currentIndex,
              icon: Icons.pie_chart_outline,
              activeIcon: Icons.pie_chart,
              label: 'Budget',
              onSelect: onSelect,
            ),
            _NavItem(
              index: 4,
              currentIndex: currentIndex,
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
              onSelect: onSelect,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onSelect,
  });

  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final active = index == currentIndex;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onSelect(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? KoloColors.primaryPastel : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? activeIcon : icon,
                size: 22,
                color: active ? KoloColors.primary : KoloColors.textMuted,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? KoloColors.primary : KoloColors.textMuted,
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiNavItem extends StatelessWidget {
  const _AiNavItem({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final active = currentIndex == 2;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => onSelect(2),
        child: Transform.translate(
          offset: const Offset(0, -12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: const Key('kolo_ai_nav_bubble'),
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: KoloColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x557C3AED),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: active ? Colors.white : KoloColors.primary,
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'AI',
                style: TextStyle(
                  color: active ? KoloColors.primary : KoloColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
