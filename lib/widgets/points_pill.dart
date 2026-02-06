import 'package:flutter/material.dart';

import '../app/theme/app_radius.dart';
import '../app/theme/app_shadows.dart';
import '../app/theme/app_colors.dart';

class PointsPill extends StatelessWidget {
  final int points;
  final String label;

  const PointsPill({
    super.key,
    required this.points,
    this.label = 'pts',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final outline = Colors.white.withValues(alpha: isDark ? 0.10 : 0.22);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: AppColors.gBubblePrimary,
        borderRadius: BorderRadius.circular(AppRadius.rPill),
        boxShadow: AppShadows.soft(context),
        border: Border.all(color: outline, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 18, color: scheme.onPrimary),
          const SizedBox(width: 6),
          Text(
            '$points $label',
            style: TextStyle(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
