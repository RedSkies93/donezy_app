import 'package:flutter/material.dart';
import '../app/theme/app_radius.dart';
import '../app/theme/app_shadows.dart';

class CuteToggle<T> extends StatelessWidget {
  final T value;
  final List<CuteToggleOption<T>> options;
  final ValueChanged<T> onChanged;

  const CuteToggle({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? scheme.surfaceContainerHighest : scheme.surface;
    final outline = Colors.white.withValues(alpha: isDark ? 0.10 : 0.22);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.rPill),
        boxShadow: AppShadows.soft(context),
        border: Border.all(color: outline, width: 1),
      ),
      child: Row(
        children: [
          for (final opt in options) ...[
            Expanded(
              child: _CuteToggleChip<T>(
                label: opt.label,
                selected: opt.value == value,
                onTap: () => onChanged(opt.value),
              ),
            ),
            if (opt != options.last) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _CuteToggleChip<T> extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CuteToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fill = selected
        ? scheme.primaryContainer
        : (isDark ? scheme.surfaceContainerHighest : scheme.surface);

    final outline = Colors.white.withValues(alpha: isDark ? 0.10 : 0.18);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.rPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadius.rPill),
            border: Border.all(color: outline, width: 1),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CuteToggleOption<T> {
  final T value;
  final String label;

  const CuteToggleOption({required this.value, required this.label});
}
