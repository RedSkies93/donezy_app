import 'package:flutter/material.dart';

import '../../models/task_model.dart';
import '../ruled_paper_dialog.dart';
import '../bubble_button.dart';

class TaskEditResult {
  final String title;
  final int pointsValue;
  final DateTime? dueDate;
  final bool clearDueDate;

  const TaskEditResult({
    required this.title,
    required this.pointsValue,
    required this.dueDate,
    required this.clearDueDate,
  });
}

class TaskEditDialog extends StatefulWidget {
  final TaskModel task;

  const TaskEditDialog({super.key, required this.task});

  static Future<TaskEditResult?> show(BuildContext context, TaskModel task) {
    return showDialog<TaskEditResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => TaskEditDialog(task: task),
    );
  }

  @override
  State<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<TaskEditDialog> {
  late final TextEditingController _title;
  late int _points;
  DateTime? _dueDate;
  bool _clearDue = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task.title);
    _points = widget.task.pointsValue;
    _dueDate = widget.task.dueDate;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _todayStart() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String _mmdd(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$mm/$dd';
  }

  void _setDue(DateTime d) {
    setState(() {
      _dueDate = _dateOnly(d);
      _clearDue = false;
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initial = _dueDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOnly(initial),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    _setDue(picked);
  }

  void _clearDueDate() {
    setState(() {
      _dueDate = null;
      _clearDue = true;
    });
  }

  void _bumpPoints(int delta) {
    setState(() {
      _points = (_points + delta).clamp(0, 999);
    });
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;

    Navigator.of(context).pop(
      TaskEditResult(
        title: title,
        pointsValue: _points,
        dueDate: _dueDate,
        clearDueDate: _clearDue,
      ),
    );
  }

  Widget _chip({
    required String label,
    required VoidCallback onTap,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(width: 1),
          ),
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Center(child: Icon(icon)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final due = _dueDate;

    return RuledPaperDialog(
      title: 'Edit Task ✏️',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          TextField(
            controller: _title,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Task name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),

          const SizedBox(height: 16),

          // Points (cute stepper)
          Row(
            children: [
              const Text('Points',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              _stepperButton(
                icon: Icons.remove_circle_outline_rounded,
                onTap: () => _bumpPoints(-1),
                onLongPress: () => _bumpPoints(-5),
                tooltip: '-1 (hold: -5)',
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(width: 1),
                ),
                child: Text('$_points',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              _stepperButton(
                icon: Icons.add_circle_outline_rounded,
                onTap: () => _bumpPoints(1),
                onLongPress: () => _bumpPoints(5),
                tooltip: '+1 (hold: +5)',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Due date quick picks + pick/clear
          Row(
            children: [
              const Text('Due date',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              if (due != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(width: 1),
                  ),
                  child: Text('Due ${_mmdd(due)}',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
            ],
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _chip(label: 'Today', onTap: () => _setDue(_todayStart())),
              _chip(
                  label: 'Tomorrow',
                  onTap: () =>
                      _setDue(_todayStart().add(const Duration(days: 1)))),
              _chip(
                  label: 'Next Week',
                  onTap: () =>
                      _setDue(_todayStart().add(const Duration(days: 7)))),
              _chip(label: 'Pick…', onTap: _pickDueDate),
              _chip(label: 'Clear', onTap: _clearDueDate),
            ],
          ),

          const SizedBox(height: 18),

          // Buttons
          Row(
            children: [
              Expanded(
                child: BubbleButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BubbleButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
