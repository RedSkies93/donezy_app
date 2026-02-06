import 'package:flutter/material.dart';

class SparkleOverlay extends StatelessWidget {
  const SparkleOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Phase 2: simple decorative dots; Phase 2.5 replaces with stickers/lottie.
    final c1 = scheme.primary.withValues(alpha: isDark ? 0.18 : 0.10);
    final c2 = scheme.secondary.withValues(alpha: isDark ? 0.16 : 0.08);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(top: 10, right: 16, child: _dot(8, c1)),
          Positioned(top: 28, right: 36, child: _dot(5, c2)),
          Positioned(bottom: 14, left: 18, child: _dot(6, c2)),
          Positioned(bottom: 26, left: 40, child: _dot(4, c1)),
        ],
      ),
    );
  }

  Widget _dot(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
