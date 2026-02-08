import '../../core/action_result.dart';

class ToggleRewardEnabled {
  Future<ActionResult<void>> run() async {
    // Phase 1: safe no-op (reward enable/disable wiring comes later).
// This action must never throw.
    return const ActionResult.success();
  }
}
