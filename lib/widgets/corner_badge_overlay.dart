import 'package:flutter/material.dart';
import 'cute_icon_badge.dart';

class CornerBadgeOverlay extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Alignment alignment;

  const CornerBadgeOverlay({
    super.key,
    required this.icon,
    this.label,
    this.alignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: CuteIconBadge(icon: icon, label: label),
        ),
      ),
    );
  }
}
