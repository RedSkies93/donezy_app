import '../../core/action_result.dart';
import '../../services/task_service.dart';

class ToggleDoneAction {
  Future<ActionResult<void>> run({
    required TaskService service,
    required String taskId,
  }) async {
    await service.toggleDone(taskId);
    return const ActionResult.success();
  }
}
