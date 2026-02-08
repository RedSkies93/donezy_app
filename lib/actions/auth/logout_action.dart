import '../../core/action_result.dart';

class LogoutAction {
  Future<ActionResult<void>> run() async {
    // Phase 1: safe no-op (auth wiring comes later).
// This action must never throw.
    return const ActionResult.success();
  }
}
