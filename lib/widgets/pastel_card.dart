import 'package:flutter/material.dart';
import '../app/theme/app_radius.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_shadows.dart';

class PastelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Gradient? gradient;

  /// Optional overlay widget (sparkles, stickers, corner icons, etc.)
  /// Rendered on top of the card content.
  final Widget? overlay;

  const PastelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.gradient,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    final g = gradient ??
        (Theme.of(context).brightness == Brightness.dark
            ? null
            : AppColors.gCardSoft);

    final bgColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.rCard),
        gradient: g,
        color: g == null ? bgColor : null,
        boxShadow: AppShadows.soft(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.rCard),
        child: Stack(
          children: [
            Padding(
              padding: padding,
              child: child,
            ),
            if (overlay != null) Positioned.fill(child: overlay!),
          ],
        ),
      ),
    );
  }
}
