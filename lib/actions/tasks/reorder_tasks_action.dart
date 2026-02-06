import '../../core/action_result.dart';
import '../../services/task_service.dart';

class ReorderTasksAction {
  Future<ActionResult> run({
    required TaskService service,
    required int oldIndex,
    required int newIndex,
    required bool canReorder,
  }) async {
        if (!canReorder) {
      return const ActionResult.success();
    }
    if (oldIndex < 0 || newIndex < 0) {
      return const ActionResult.success();
    }
    service.reorder(oldIndex, newIndex);
    return const ActionResult.success();
  }
}

