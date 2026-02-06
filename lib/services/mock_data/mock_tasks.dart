import '../../models/task_model.dart';

class MockTasks {
  static List<TaskModel> seed() => [
        const TaskModel(id: 't1', title: 'Make bed', isStarred: true, pointsValue: 10, order: 0),
        const TaskModel(id: 't2', title: 'Brush teeth', pointsValue: 5, order: 1),
        const TaskModel(id: 't3', title: 'Pick up toys', pointsValue: 15, order: 2),
      ];
}
