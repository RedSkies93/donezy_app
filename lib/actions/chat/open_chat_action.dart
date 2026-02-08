import '../../core/action_result.dart';

class OpenChat {
  Future<ActionResult<void>> run() async {
    // Phase 1: safe no-op (chat navigation comes later).
// This action must never throw.
    return const ActionResult.success();
  }
}
