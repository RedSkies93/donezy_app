import '../../core/action_result.dart';
import '../../services/task_service.dart';

class ToggleStarAction {
  Future<ActionResult<void>> run({
    required TaskService service,
    required String taskId,
  }) async {
    await service.toggleStar(taskId);
    return const ActionResult.success();
  }
}
