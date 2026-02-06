import '../models/task_model.dart';
import 'task_store.dart';
import 'child_store.dart';
import 'mock_data/mock_tasks.dart';

class TaskService {
  final TaskStore store;
  final ChildStore childStore;

  TaskService(this.store, this.childStore);

  Future<void> load() async {
    store.setTasks(MockTasks.seed());
  }

  Future<void> toggleStar(String taskId) async {
    final t = store.tasks.firstWhere((x) => x.id == taskId);
    store.updateTask(t.copyWith(isStarred: !t.isStarred));
  }

  Future<void> addTask(String title) async {
    final clean = title.trim();
    if (clean.isEmpty) return;

    final id = 't_${DateTime.now().microsecondsSinceEpoch}';
    final maxOrder = store.tasks.isEmpty
        ? -1
        : store.tasks.map((t) => t.order).reduce((a, b) => a > b ? a : b);

    final created = TaskModel(
      id: id,
      title: clean,
      isStarred: false,
      isEnabled: true,
      isDone: false,
      pointsValue: 10,
      order: maxOrder + 1,
      dueDate: null,
    );

    store.setTasks([...store.tasks, created]);
  }

  Future<void> renameTask(String taskId, String newTitle) async {
    final clean = newTitle.trim();
    if (clean.isEmpty) return;

    final t = store.tasks.firstWhere((x) => x.id == taskId);
    store.updateTask(t.copyWith(title: clean));
  }

  Future<void> setPointsValue(String taskId, int pointsValue) async {
    final t = store.tasks.firstWhere((x) => x.id == taskId);
    final safe = pointsValue.clamp(0, 999);
    store.updateTask(t.copyWith(pointsValue: safe));
  }

  Future<void> setDueDate(String taskId, DateTime? dueDate) async {
    final t = store.tasks.firstWhere((x) => x.id == taskId);
    final dateOnly = dueDate == null ? null : DateTime(dueDate.year, dueDate.month, dueDate.day);
    store.updateTask(t.copyWith(dueDate: dateOnly));
  }

  Future<void> deleteTask(String taskId) async {
    store.setTasks(store.tasks.where((t) => t.id != taskId).toList());
  }

  Future<void> deleteMany(Set<String> ids) async {
    if (ids.isEmpty) return;
    store.setTasks(store.tasks.where((t) => !ids.contains(t.id)).toList());
  }

  Future<void> toggleDone(String taskId) async {
    final t = store.tasks.firstWhere((x) => x.id == taskId);
    final nextDone = !t.isDone;

    if (nextDone) {
      childStore.earn(t.pointsValue);
    } else {
      childStore.spend(t.pointsValue);
    }

    store.updateTask(t.copyWith(isDone: nextDone));
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = store.tasks.toList();
    if (newIndex > oldIndex) newIndex -= 1;

    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    final reOrdered = <TaskModel>[];
    for (var i = 0; i < list.length; i++) {
      reOrdered.add(list[i].copyWith(order: i));
    }

    store.setTasks(reOrdered);
  }
}
