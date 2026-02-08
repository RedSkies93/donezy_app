import 'package:flutter/material.dart';

import '../../core/action_result.dart';
import '../../services/task_service.dart';
import '../../services/task_store.dart';
import '../../widgets/ruled_paper_dialog.dart';
import '../../widgets/bubble_button.dart';

class ConfirmBulkDeleteAction {
  Future<ActionResult<void>> run({
    required BuildContext context,
    required TaskService service,
    required TaskStore store,
  }) async {
    final count = store.selectedCount;
    if (count == 0) {
      return const ActionResult.failure('No tasks selected.');
    }

    final ok = await showRuledPaperDialog<bool>(
      context: context,
      title: 'Delete $count tasks?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This will permanently remove $count selected tasks.'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: BubbleButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BubbleButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (ok != true) return const ActionResult.cancelled();

    await service.deleteMany(store.selectedIds);
    store.setBulkMode(false);
    return const ActionResult.success();
  }
}






