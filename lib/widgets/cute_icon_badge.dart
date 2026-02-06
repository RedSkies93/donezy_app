import 'package:flutter/material.dart';

import '../app/theme/app_radius.dart';
import '../app/theme/app_shadows.dart';

class CuteIconBadge extends StatelessWidget {
  final IconData icon;
  final String? label;

  const CuteIconBadge({
    super.key,
    required this.icon,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fill = isDark ? scheme.surfaceContainerHighest : scheme.surface;
    final outline = Colors.white.withValues(alpha: isDark ? 0.10 : 0.22);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.rPill),
        boxShadow: AppShadows.soft(context),
        border: Border.all(color: outline, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(
              label!,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
