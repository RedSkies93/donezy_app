import '../../core/action_result.dart';

class SetChatScope {
  Future<ActionResult<void>> run() async {
    // Phase 1: safe no-op (scope selection persistence comes later).
// This action must never throw.
    return const ActionResult.success();
  }
}
