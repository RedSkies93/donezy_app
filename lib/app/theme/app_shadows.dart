import 'package:flutter/material.dart';

class AppShadows {
  // Soft, cute, airy shadow set (no harsh lines)
  static List<BoxShadow> soft(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Keep shadow subtler in dark mode
    final opacity = isDark ? 0.18 : 0.10;

    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity * 0.65),
        blurRadius: 6,
        offset: const Offset(0, 3),
      ),
    ];
  }
}
