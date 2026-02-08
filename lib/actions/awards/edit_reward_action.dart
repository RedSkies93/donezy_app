import '../../core/action_result.dart';

class EditReward {
  Future<ActionResult<void>> run() async {
    // Phase 1: safe no-op (reward editing UI comes later).
// This action must never throw.
    return const ActionResult.success();
  }
}
