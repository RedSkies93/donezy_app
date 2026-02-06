import 'package:flutter/material.dart';

import '../../core/action_result.dart';
import '../../services/task_service.dart';
import '../../models/task_model.dart';

class PickDueDateAction {
  Future<ActionResult<void>> run({
    required BuildContext context,
    required TaskService service,
    required TaskModel task,
  }) async {
    final now = DateTime.now();
    final initial = task.dueDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (picked == null) return const ActionResult.cancelled();

    await service.setDueDate(task.id, picked);
    return const ActionResult.success();
  }
}
