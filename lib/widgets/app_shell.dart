import 'package:flutter/material.dart';

import '../app/theme/app_radius.dart';
import '../app/theme/app_shadows.dart';
import '../app/theme/app_colors.dart';
import 'press_bounce.dart';

class AppShell extends StatelessWidget {
  final String title;
  final Widget body;

  final int currentIndex;
  final ValueChanged<int> onNavTap;

  const AppShell({
    super.key,
    required this.title,
    required this.body,
    required this.currentIndex,
    required this.onNavTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: body),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: _CuteBubbleDock(
            currentIndex: currentIndex,
            onTap: onNavTap,
          ),
        ),
      ),
    );
  }
}

class _CuteBubbleDock extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _CuteBubbleDock({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dockColor = isDark ? scheme.surfaceContainerHighest : scheme.surface;
    final outline = Colors.white.withValues(alpha: isDark ? 0.10 : 0.20);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: dockColor,
        borderRadius: BorderRadius.circular(AppRadius.rPill),
        boxShadow: AppShadows.soft(context),
        border: Border.all(color: outline, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DockBubble(
              icon: Icons.home_rounded,
              label: 'Dash',
              selected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
          ),
          Expanded(
            child: _DockBubble(
              icon: Icons.chat_bubble_rounded,
              label: 'Chat',
              selected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
          ),
          Expanded(
            child: _DockBubble(
              icon: Icons.emoji_events_rounded,
              label: 'Awards',
              selected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
          ),
          Expanded(
            child: _DockBubble(
              icon: Icons.settings_rounded,
              label: 'Settings',
              selected: currentIndex == 3,
              onTap: () => onTap(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _DockBubble extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DockBubble({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bubbleFill = selected
        ? AppColors.gBubblePrimary
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (isDark ? scheme.surfaceContainerHighest : scheme.surface),
              (isDark ? scheme.surfaceContainerHighest : scheme.surface),
            ],
          );

    final outline = Colors.white.withValues(alpha: isDark ? 0.10 : 0.18);
    final iconColor = selected ? scheme.onPrimary : scheme.onSurface;
    final textColor = selected ? scheme.onPrimary : scheme.onSurface.withValues(alpha: 0.80);

    return PressBounce(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: bubbleFill,
                borderRadius: BorderRadius.circular(AppRadius.rPill),
                border: Border.all(color: outline, width: 1),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                fontSize: 12,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
