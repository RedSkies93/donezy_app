import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/app_shell.dart';
import '../../widgets/pastel_card.dart';
import '../../widgets/screen_background.dart';
import '../../widgets/bubble_button.dart';
import '../../widgets/points_pill.dart';
import '../../widgets/tasks/task_card.dart';
import '../../widgets/tasks/bulk_action_bar.dart';
import '../../widgets/tasks/task_filter_row.dart';

import '../../core/asset_registry.dart';
import '../../core/constants.dart';

import '../../services/task_service.dart';
import '../../services/task_store.dart';
import '../../services/child_store.dart';

import '../../actions/tasks/add_task_action.dart';
import '../../actions/tasks/toggle_done_action.dart';
import '../../actions/tasks/toggle_bulk_mode_action.dart';
import '../../actions/tasks/confirm_bulk_delete_action.dart';

import '../../actions/navigation/go_to_child_dashboard_action.dart';
import '../../actions/navigation/go_to_messages_action.dart';
import '../../actions/navigation/go_to_awards_action.dart';
import '../../actions/navigation/go_to_settings_action.dart';

class ChildDashboardPage extends StatefulWidget {
  const ChildDashboardPage({super.key});

  @override
  State<ChildDashboardPage> createState() => _ChildDashboardPageState();
}

class _ChildDashboardPageState extends State<ChildDashboardPage> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: discarded_futures
      context.read<TaskService>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskStore = context.watch<TaskStore>();
    final points = context.watch<ChildStore>().points;
    final service = context.read<TaskService>();
    final toggleDone = ToggleDoneAction();
    final toggleBulk = ToggleBulkModeAction();
    final confirmBulkDelete = ConfirmBulkDeleteAction();
    final goChildDash = GoToChildDashboardAction();
    final goMsg = GoToMessagesAction();
    final goAwards = GoToAwardsAction();
    final goSettings = GoToSettingsAction();

    final visible = taskStore.visibleTasks;
    void selectAllVisible() {
      for (final t in visible) {
        if (!taskStore.isSelected(t.id)) {
          taskStore.toggleSelected(t.id);
        }
      }
    }

    return AppShell(
      title: 'Child Dashboard',
      currentIndex: 0,
      onNavTap: (i) {
        switch (i) {
          case 0:
            goChildDash.run(context);
            break;
          case 1:
            goMsg.run(context);
            break;
          case 2:
            goAwards.run(context);
            break;
          case 3:
            goSettings.run(context);
            break;
        }
      },
      body: ScreenBackground(
        assetPath: AssetRegistry.bgChild,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            PastelCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hey Superstar ⭐',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  PointsPill(points: points),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            TaskFilterRow(
              selectedIndex: taskStore.filter.index,
              onSelect: (i) => taskStore.setFilter(TaskFilterMode.values[i]),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            BubbleButton(
              onPressed: () =>
                  AddTaskAction().run(context: context, service: service),
              child: const Text('Add Task'),
            ),
            const SizedBox(height: 10),
            BubbleButton(
              onPressed: () => toggleBulk.run(store: taskStore),
              child: Text(taskStore.bulkMode ? 'Exit Bulk Mode' : 'Bulk Mode'),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            if (taskStore.bulkMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BulkActionBar(
                  selectedCount: taskStore.selectedCount,
                  onSelectAllVisible: selectAllVisible,
                  onClear: taskStore.clearSelection,
                  onCancel: () => taskStore.setBulkMode(false),
                  onDelete: () => confirmBulkDelete.run(
                      context: context, service: service, store: taskStore),
                ),
              ),
            if (visible.isEmpty)
              const PastelCard(child: Text('No tasks match this filter yet.'))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final t = visible[index];

                  return Padding(
                    key: ValueKey('task_${t.id}'),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TaskCard(
                      task: t,
                      isSelected: taskStore.isSelected(t.id),
                      dragHandle: null,
                      onToggleStar: null, // child: hidden

                      onToggleDone: () =>
                          toggleDone.run(service: service, taskId: t.id),
                      onPickDueDate: null, // child: hidden
                      onEdit: null, // child: hidden

                      onLongPress: null, // child: hidden
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
