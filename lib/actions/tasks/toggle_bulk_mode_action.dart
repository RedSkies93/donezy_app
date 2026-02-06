import '../../core/action_result.dart';
import '../../services/task_store.dart';

class ToggleBulkModeAction {
  Future<ActionResult<void>> run({
    required TaskStore store,
  }) async {
    store.toggleBulkMode();
    return const ActionResult.success();
  }
}
