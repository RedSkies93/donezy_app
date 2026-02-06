import '../../core/action_result.dart';
import '../../services/task_service.dart';

/// Legacy name kept for now.
/// Phase 3 uses "Done" (completion) instead of "Enabled".
class ToggleEnabledAction {
  Future<ActionResult<void>> run({
    required TaskService service,
    required String taskId,
  }) async {
    await service.toggleDone(taskId);
    return const ActionResult.success();
  }
}
