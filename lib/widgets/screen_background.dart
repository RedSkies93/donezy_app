import 'package:flutter/material.dart';

import '../core/utils.dart';

class ScreenBackground extends StatelessWidget {
  final String? assetPath; // should come from AssetRegistry
  final Widget child;

  const ScreenBackground({
    super.key,
    required this.child,
    this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    if (assetPath == null) return child;

    return FutureBuilder<bool>(
      future: AppUtils.assetExists(assetPath!),
      builder: (context, snap) {
        final ok = snap.data == true;

        return Stack(
          children: [
            if (ok)
              Positioned.fill(
                child: Image.asset(
                  assetPath!,
                  fit: BoxFit.cover,
                ),
              ),
            // Soft overlay so content stays readable
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.10),
                ),
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}
