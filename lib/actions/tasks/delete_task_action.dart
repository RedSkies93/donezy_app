import 'package:flutter/material.dart';

import '../../core/action_result.dart';
import '../../services/task_service.dart';
import '../../models/task_model.dart';
import '../../widgets/ruled_paper_dialog.dart';
import '../../widgets/bubble_button.dart';

class DeleteTaskAction {
  Future<ActionResult<void>> run({
    required BuildContext context,
    required TaskService service,
    required TaskModel task,
  }) async {
    final ok = await showRuledPaperDialog<bool>(
      context: context,
      title: 'Delete Task?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Are you sure you want to delete:'),
          const SizedBox(height: 8),
          Text(
            '“${task.title}”',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: BubbleButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BubbleButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (ok != true) return const ActionResult.cancelled();

    await service.deleteTask(task.id);
    return const ActionResult.success();
  }
}
