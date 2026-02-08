import 'package:flutter/material.dart';

/// Reusable ruled-paper dialog shell (Phase 3: simple, asset-free).
/// Phase 2/2.5 will add cute ruled-paper background, stickers, clouds, sparkles, etc.
class RuledPaperDialog extends StatelessWidget {
  final String title;
  final Widget child;

  const RuledPaperDialog({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Helper used by actions/screens:
/// showRuledPaperDialog(T) with generic return type, e.g. T = bool
Future<T?> showRuledPaperDialog<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => RuledPaperDialog(title: title, child: child),
  );
}
