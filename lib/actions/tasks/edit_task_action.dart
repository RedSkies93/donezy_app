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
    final newTitle = result.title.trim();
    final changedTitle = newTitle != task.title;
    final changedPoints = result.pointsValue != task.pointsValue;
    final changedDue = result.clearDueDate || (result.dueDate != task.dueDate);

    if (changedTitle || changedPoints || changedDue) {
      await service.editTask(
        task.id,
        title: changedTitle ? newTitle : null,
        pointsValue: changedPoints ? result.pointsValue : null,
        dueDate: (!result.clearDueDate && result.dueDate != task.dueDate)
            ? result.dueDate
            : null,
        clearDueDate: result.clearDueDate,
      );
    }

    return const ActionResult.success();
  }
}
