import '../../core/action_result.dart';

class SwitchModeAction {
  Future<ActionResult<void>> run() async {
    // Phase 1: safe no-op (mode switching wiring comes later).
// This action must never throw.
    return const ActionResult.success();
  }
}
