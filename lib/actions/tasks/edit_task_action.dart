import 'package:flutter/material.dart';

import '../../core/action_result.dart';
import '../../models/task_model.dart';
import '../../services/task_service.dart';
import '../../widgets/tasks/task_edit_dialog.dart';

class EditTaskAction {
  Future<ActionResult<void>> run({
    required BuildContext context,
    required TaskService service,
    required TaskModel task,
  }) async {
    final result = await TaskEditDialog.show(context, task);
    if (result == null) return const ActionResult.cancelled();

    // Apply changes (mock-first)
    if (result.title.trim() != task.title) {
      await service.renameTask(task.id, result.title);
    }

    if (result.pointsValue != task.pointsValue) {
      await service.setPointsValue(task.id, result.pointsValue);
    }

    // Due date: either clear or set
    if (result.clearDueDate) {
      await service.setDueDate(task.id, null);
    } else if (result.dueDate != task.dueDate) {
      await service.setDueDate(task.id, result.dueDate);
    }

    return const ActionResult.success();
  }
}
