import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task_model.dart';
import 'firestore_paths.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _tasks(String familyId) =>
      _db.collection(FirestorePaths.tasksCol(familyId));

  Stream<List<TaskModel>> watchTasks(String familyId) {
    return _tasks(familyId)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map((d) => _fromDoc(d.id, d.data())).toList());
  }

  Future<String> addTask(String familyId, TaskModel task) async {
    final ref = _tasks(familyId).doc();
    await ref.set(_toMap(task, idOverride: ref.id));
    return ref.id;
  }

  Future<void> updateTask(String familyId, TaskModel task) async {
    if (task.id.isEmpty) return;
    await _tasks(familyId).doc(task.id).set(
          _toMap(task),
          SetOptions(merge: true),
        );
  }

  Future<void> deleteTask(String familyId, String taskId) async {
    await _tasks(familyId).doc(taskId).delete();
  }

  Future<void> deleteMany(String familyId, Set<String> ids) async {
    if (ids.isEmpty) return;
    final batch = _db.batch();
    for (final id in ids) {
      batch.delete(_tasks(familyId).doc(id));
    }
    await batch.commit();
  }

  Future<void> batchUpdateOrder(String familyId, List<TaskModel> ordered) async {
    final batch = _db.batch();
    for (var i = 0; i < ordered.length; i++) {
      final t = ordered[i];
      if (t.id.isEmpty) continue;
      batch.update(_tasks(familyId).doc(t.id), <String, dynamic>{
        'order': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  TaskModel _fromDoc(String id, Map<String, dynamic> m) {
    DateTime? due;
    final raw = m['dueDate'];
    if (raw is Timestamp) due = raw.toDate();
    if (raw is String) due = DateTime.tryParse(raw);

    return TaskModel(
      id: id,
      title: (m['title'] as String?) ?? '',
      pointsValue: (m['pointsValue'] as int?) ?? 1,
      dueDate: due,
      isCompleted: (m['isCompleted'] as bool?) ?? false,
      isStarred: (m['isStarred'] as bool?) ?? false,
      isEnabled: (m['isEnabled'] as bool?) ?? true,
      order: (m['order'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> _toMap(TaskModel t, {String? idOverride}) {
    return <String, dynamic>{
      'id': idOverride ?? t.id,
      'title': t.title,
      'pointsValue': t.pointsValue,
      'dueDate': t.dueDate == null ? null : Timestamp.fromDate(t.dueDate!),
      'isCompleted': t.isCompleted,
      'isStarred': t.isStarred,
      'isEnabled': t.isEnabled,
      'order': t.order,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
