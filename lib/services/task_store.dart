import 'package:flutter/foundation.dart';
import '../models/task_model.dart';

enum TaskFilterMode {
  all,
  starred,
  dueSoon,
  overdue,
}

class TaskStore extends ChangeNotifier {
  List<TaskModel> _tasks = const [];

  // Bulk mode state
  bool _bulkMode = false;
  final Set<String> _selectedIds = <String>{};

  // Filter state
  TaskFilterMode _filter = TaskFilterMode.all;

  List<TaskModel> get tasks => _tasks;
  bool get bulkMode => _bulkMode;

  Set<String> get selectedIds => _selectedIds;
  int get selectedCount => _selectedIds.length;

  TaskFilterMode get filter => _filter;

  DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  List<TaskModel> get visibleTasks {
    final base = _tasks;

    switch (_filter) {
      case TaskFilterMode.all:
        return base;

      case TaskFilterMode.starred:
        return base.where((t) => t.isStarred).toList(growable: false);

      case TaskFilterMode.dueSoon:
        final start = _todayStart();
        final end = start.add(const Duration(days: 3));
        return base
            .where((t) => t.dueDate != null)
            .where((t) => !t.isDone)
            .where((t) => t.dueDate!.isAfter(start.subtract(const Duration(seconds: 1))))
            .where((t) => t.dueDate!.isBefore(end.add(const Duration(days: 1))))
            .toList(growable: false);

      case TaskFilterMode.overdue:
        final start = _todayStart();
        return base
            .where((t) => t.dueDate != null)
            .where((t) => !t.isDone)
            .where((t) => t.dueDate!.isBefore(start))
            .toList(growable: false);
    }
  }

  void setTasks(List<TaskModel> items) {
    final sorted = items.toList()..sort((a, b) => a.order.compareTo(b.order));
    _tasks = List.unmodifiable(sorted);

    final existing = _tasks.map((t) => t.id).toSet();
    _selectedIds.removeWhere((id) => !existing.contains(id));

    notifyListeners();
  }

  void updateTask(TaskModel updated) {
    final idx = _tasks.indexWhere((t) => t.id == updated.id);
    if (idx < 0) return;

    final next = _tasks.toList();
    next[idx] = updated;
    next.sort((a, b) => a.order.compareTo(b.order));
    _tasks = List.unmodifiable(next);
    notifyListeners();
  }

  // Filter controls
  void setFilter(TaskFilterMode mode) {
    _filter = mode;
    notifyListeners();
  }

  // Bulk mode controls
  void setBulkMode(bool value) {
    _bulkMode = value;
    if (!value) _selectedIds.clear();
    notifyListeners();
  }

  void toggleBulkMode() => setBulkMode(!_bulkMode);

  bool isSelected(String taskId) => _selectedIds.contains(taskId);

    void selectAll(Iterable<String> ids) {
    var changed = false;
    for (final id in ids) {
      if (_selectedIds.add(id)) changed = true;
    }
    if (changed) notifyListeners();
  }
void toggleSelected(String taskId) {
    if (_selectedIds.contains(taskId)) {
      _selectedIds.remove(taskId);
    } else {
      _selectedIds.add(taskId);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }
  // ---------------------------------------------------------
  // Phase 2 compatibility helpers (used by TaskService)
  // ---------------------------------------------------------
  void replaceAll(List<TaskModel> items) => setTasks(items);

  void addLocal(TaskModel task) {
    final next = _tasks.toList()..add(task);
    setTasks(next.cast<TaskModel>());
  }

  void upsertLocal(TaskModel task) {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx < 0) {
      addLocal(task);
      return;
    }
    updateTask(task);
  }

  void deleteLocal(String taskId) {
    final next = _tasks.where((t) => t.id != taskId).toList();
    setTasks(next.cast<TaskModel>());
  }

  /// Reorders the *full* list order (ignores filter). Returns the updated list for persistence.
  List<TaskModel> reorderLocal(int oldIndex, int newIndex) {
    final list = _tasks.toList().cast<TaskModel>();
    if (oldIndex < 0 || oldIndex >= list.length) return list;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > list.length) newIndex = list.length;

    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    final updated = <TaskModel>[];
    for (var i = 0; i < list.length; i++) {
      updated.add(list[i].copyWith(order: i));
    }
    setTasks(updated);
    return updated;
  }
}
