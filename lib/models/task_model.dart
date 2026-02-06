class TaskModel {
  final String id;
  final String title;

  final bool isStarred;
  final bool isEnabled;

  // Phase 3: completion + points
  final bool isDone;
  final int pointsValue;

  // Phase 3: reorder support
  final int order;

  final DateTime? dueDate;

  const TaskModel({
    required this.id,
    required this.title,
    this.isStarred = false,
    this.isEnabled = true,
    this.isDone = false,
    this.pointsValue = 10,
    this.order = 0,
    this.dueDate,
  });

  TaskModel copyWith({
    String? title,
    bool? isStarred,
    bool? isEnabled,
    bool? isDone,
    int? pointsValue,
    int? order,
    DateTime? dueDate,
  }) {
    return TaskModel(
      id: id,
      title: title ?? this.title,
      isStarred: isStarred ?? this.isStarred,
      isEnabled: isEnabled ?? this.isEnabled,
      isDone: isDone ?? this.isDone,
      pointsValue: pointsValue ?? this.pointsValue,
      order: order ?? this.order,
      dueDate: dueDate ?? this.dueDate,
    );
  }
}
