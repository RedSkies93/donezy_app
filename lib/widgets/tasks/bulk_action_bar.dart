import 'package:flutter/material.dart';

class BulkActionBar extends StatelessWidget {
  final int selectedCount;

  final VoidCallback onSelectAllVisible;
  final VoidCallback onClear;

  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const BulkActionBar({
    super.key,
    required this.selectedCount,
    required this.onSelectAllVisible,
    required this.onClear,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget pillButton({
      required VoidCallback onPressed,
      required String label,
    }) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: TextButton(
          onPressed: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(label),
          ),
        ),
      );
    }

    Widget primaryPill({
      required VoidCallback onPressed,
      required String label,
    }) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: ElevatedButton(
          onPressed: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(label),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT: Selected count (fixed width)
          SizedBox(
            width: 74,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SELECTED',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedCount.toString(),
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // RIGHT: Actions that WRAP to avoid overflow
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: [
                pillButton(onPressed: onSelectAllVisible, label: 'Select All'),
                pillButton(onPressed: onClear, label: 'Clear'),
                pillButton(onPressed: onCancel, label: 'Exit'),
                primaryPill(onPressed: onDelete, label: 'Delete'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
