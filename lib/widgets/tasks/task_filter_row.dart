import 'package:flutter/material.dart';

class TaskFilterRow extends StatelessWidget {
  final int selectedIndex; // 0=all, 1=starred, 2=dueSoon, 3=overdue
  final ValueChanged<int> onSelect;

  const TaskFilterRow({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  Widget _pill(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(width: 1),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                decoration: active ? TextDecoration.underline : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _pill('All', selectedIndex == 0, () => onSelect(0)),
            const SizedBox(width: 10),
            _pill('Starred', selectedIndex == 1, () => onSelect(1)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _pill('Due Soon', selectedIndex == 2, () => onSelect(2)),
            const SizedBox(width: 10),
            _pill('Overdue', selectedIndex == 3, () => onSelect(3)),
          ],
        ),
      ],
    );
  }
}
