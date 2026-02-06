import 'package:flutter/material.dart';

import '../../models/task_model.dart';
import '../pastel_card.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final bool isSelected;

  /// Optional drag handle widget (dashboards pass ReorderableDragStartListener)
  final Widget? dragHandle;

  final VoidCallback? onToggleStar;
  final VoidCallback onToggleDone;
  final VoidCallback? onPickDueDate;
  final VoidCallback? onEdit;
  final VoidCallback? onLongPress;

  const TaskCard({
    super.key,
    required this.task,
    required this.isSelected,
    this.dragHandle,
    this.onToggleStar,
    required this.onToggleDone,
    this.onPickDueDate,
    this.onEdit,
    this.onLongPress,
  });

  DateTime _todayStart() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _isOverdue {
    if (task.isDone) return false;
    final d = task.dueDate;
    if (d == null) return false;
    return d.isBefore(_todayStart());
  }

  String _mmdd(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$mm/$dd';
  }

  Widget _pill(
    BuildContext context, {
    required String label,
    required bool strong,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;

    final bg = strong
        ? cs.primary.withValues(alpha: 0.18)
        : cs.secondary.withValues(alpha: 0.14);

    final border = strong
        ? cs.primary.withValues(alpha: 0.35)
        : cs.secondary.withValues(alpha: 0.30);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _tapIcon({
    required BuildContext context,
    required IconData icon,
    VoidCallback? onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final due = task.dueDate;

    final pointsLabel = '${task.pointsValue} pts';
    final dueLabel = (due == null)
        ? 'No due'
        : (_isOverdue ? 'OVERDUE' : 'Due ${_mmdd(due)}');

    return PastelCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onEdit,
        onLongPress: (dragHandle != null) ? null : onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Far-left drag handle (dashboard passes ReorderableDragStartListener)
        if (dragHandle != null) dragHandle!,
        if (dragHandle != null) const SizedBox(width: 8),

        // Centered title (not cut off)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Align(
              alignment: Alignment.topCenter,
              child: Text(
                task.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      decoration: task.isDone ? TextDecoration.lineThrough : null,
                    ),
              ),
            ),
          ),
        ),

        // Far-right side: star at the top-right corner + done centered on the right edge
        SizedBox(
          width: 52,
          height: 44,
          child: Stack(
            children: [
              Align(
  alignment: Alignment.topRight,
  child: Container(
    decoration: BoxDecoration(
      color: task.isStarred
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      shape: BoxShape.circle,
    ),
    child: _tapIcon(
      context: context,
      icon: Icons.star_rounded,
onTap: onToggleStar,
      tooltip: 'Star',
    ),
  ),
),
              Align(
                alignment: Alignment.centerRight,
                child: _tapIcon(
                  context: context,
                  icon: task.isDone
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  onTap: onToggleDone,
                  tooltip: 'Done',
                ),
              ),
            ],
          ),
        ),
      ],
    ),

const SizedBox(height: 4),

// Pencil + calendar under the title (centered)
Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
if (onEdit != null)        if (onEdit != null) _tapIcon(
          context: context,
          icon: Icons.edit_rounded,
          onTap: onEdit,
          tooltip: 'Edit',
        ),
if (onPickDueDate != null)        if (onPickDueDate != null) _tapIcon(
          context: context,
          icon: Icons.calendar_month_rounded,
          onTap: onPickDueDate,
          tooltip: 'Due date',
        ),
      ],
    ),
  ],
),
const SizedBox(height: 10),

              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _pill(
                    context,
                    label: pointsLabel,
                    strong: false,
                    icon: Icons.bolt_rounded,
                  ),
                  _pill(
                    context,
                    label: dueLabel,
                    strong: _isOverdue,
                    icon: (due == null)
                        ? Icons.event_busy_rounded
                        : (_isOverdue
                            ? Icons.warning_rounded
                            : Icons.schedule_rounded),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.tertiary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: cs.tertiary.withValues(alpha: 0.30),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'SELECTED',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}






