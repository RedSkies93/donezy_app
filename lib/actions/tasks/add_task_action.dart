import 'package:provider/provider.dart';
import '../../services/session_store.dart';
import 'package:flutter/material.dart';

import '../../core/action_result.dart';
import '../../services/task_service.dart';
import '../../widgets/ruled_paper_dialog.dart';
import '../../widgets/bubble_button.dart';

class AddTaskAction {
  Future<ActionResult<void>> run({
    required BuildContext context,
    required TaskService service,
  }) async {
    final controller = TextEditingController();

    final result = await showRuledPaperDialog<bool>(
      context: context,
      title: 'Add a Task',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Task title',
              hintText: 'e.g., Brush teeth',
            ),
            onSubmitted: (_) => Navigator.pop(context, true),
          ),
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
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (result != true) return const ActionResult.cancelled();

    final title = controller.text.trim();
    if (title.isEmpty) {
      return const ActionResult.failure('Task title is required.');
    }
    final selectedChildId =
        Provider.of<SessionStore>(context, listen: false).selectedChildId;

    await service.addTask(title, childId: selectedChildId);
    return const ActionResult.success();
  }
}
