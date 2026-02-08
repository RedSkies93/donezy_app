class TaskModel {
  final String id;
  final String title;

  final bool isStarred;
  final bool isEnabled;
  final String? childId;

  // Phase 3: completion + points
  final bool isDone;
  final int pointsValue;

  // Phase 3: reorder support
  final int order;

  final DateTime? dueDate;

  bool get isCompleted => isDone;
  const TaskModel({
    required this.id,
    required this.title,
    this.isStarred = false,
    this.isEnabled = true,
    this.isDone = false,
    this.childId,
    this.pointsValue = 10,
    this.order = 0,
    this.dueDate,
  });

  TaskModel copyWith({
    String? id,
    bool? isCompleted,
    String? title,
    bool? isStarred,
    bool? isEnabled,
    bool? isDone,
    int? pointsValue,
    int? order,
    DateTime? dueDate,
    String? childId,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      isStarred: isStarred ?? this.isStarred,
      isEnabled: isEnabled ?? this.isEnabled,
      isDone: isDone ?? isCompleted ?? this.isDone,
      pointsValue: pointsValue ?? this.pointsValue,
      order: order ?? this.order,
      dueDate: dueDate ?? this.dueDate,
      childId: childId ?? this.childId,
    );
  }
}
