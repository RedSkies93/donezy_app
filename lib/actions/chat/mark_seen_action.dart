import '../../core/action_result.dart';

class MarkSeen {
  Future<ActionResult<void>> run() async {
    // Phase 1: safe no-op (message seen tracking comes later).
// This action must never throw.
    return const ActionResult.success();
  }
}
