import 'package:flutter/material.dart';

import '../app/theme/app_radius.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_shadows.dart';
import 'press_bounce.dart';

class BubbleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Gradient? gradient;
  final EdgeInsets padding;

  const BubbleButton({
    super.key,
    required this.child,
    this.onPressed,
    this.gradient,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    final g = gradient ?? AppColors.gBubblePrimary;

    final border = Border.all(
      color: Colors.white.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.10 : 0.22),
      width: 1,
    );

    final content = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.rPill),
        gradient: g,
        boxShadow: AppShadows.soft(context),
        border: border,
      ),
      child: Padding(
        padding: padding,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          child: Center(child: child),
        ),
      ),
    );

    return Opacity(
      opacity: isDisabled ? 0.55 : 1,
      child: PressBounce(
        onTap: onPressed,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.rPill),
          child: Material(color: Colors.transparent, child: content),
        ),
      ),
    );
  }
}
