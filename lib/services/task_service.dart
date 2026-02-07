import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../app/app_config.dart';
import '../models/task_model.dart';
import 'child_store.dart';
import 'firestore_service.dart';
import 'session_store.dart';
import 'task_store.dart';

class TaskService {
  TaskService(
    this._store,
    this._child, {
    AppConfig? config,
    SessionStore? session,
    FirestoreService? firestore,
  })  : _config = config,
        _session = session,
        _firestore = firestore;

  final TaskStore _store;
  final ChildStore _child;

  final AppConfig? _config;
  final SessionStore? _session;
  final FirestoreService? _firestore;

  StreamSubscription<List<TaskModel>>? _sub;

  bool get _firebaseOn => (_config?.enableFirebase ?? false) && _firestore != null && _session != null;

  Future<void> _ensureSignedIn() async {
    if (!_firebaseOn) return;

    final auth = FirebaseAuth.instance;
    final existing = auth.currentUser;
    if (existing != null) {
      _session!.setUserId(existing.uid);
      return;
    }

    final cred = await auth.signInAnonymously();
    _session!.setUserId(cred.user?.uid ?? '');
  }

  /// Called by dashboards (Phase 2) — keeps UI live with Firestore.
  Future<void> loadTasks() async {
    if (!_firebaseOn) return;

    await _ensureSignedIn();

    await _sub?.cancel();
    _sub = _firestore!.watchTasks(_session!.familyId).listen((tasks) {
      _store.replaceAll(tasks);
    });
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  // ---------------------------------------------------------
  // Existing API used by Actions/UI
  // ---------------------------------------------------------

  Future<void> addTask(String title) async {
    final nextOrder = _store.tasks.length;

    final task = TaskModel(
      id: '',
      title: title,
      pointsValue: 1,
      dueDate: null,
      isCompleted: false,
      isStarred: false,
      isEnabled: true,
      order: nextOrder,
    );

    if (_firebaseOn) {
      await _ensureSignedIn();
      await _firestore!.addTask(_session!.familyId, task);
      return;
    }

    // Offline fallback
    _store.addLocal(task.copyWith(id: DateTime.now().microsecondsSinceEpoch.toString()));
  }

  Future<void> toggleDone(String taskId) async {
    final t = _store.tasks.where((x) => x.id == taskId).cast<TaskModel?>().firstWhere((x) => x != null, orElse: () => null);
    if (t == null) return;

    final updated = t.copyWith(isCompleted: !t.isCompleted);
    _store.upsertLocal(updated);

    if (_firebaseOn) {
      await _ensureSignedIn();
      await _firestore!.updateTask(_session!.familyId, updated);
    }
  }

  Future<void> toggleStar(String taskId) async {
    final t = _store.tasks.where((x) => x.id == taskId).cast<TaskModel?>().firstWhere((x) => x != null, orElse: () => null);
    if (t == null) return;

    final updated = t.copyWith(isStarred: !t.isStarred);
    _store.upsertLocal(updated);

    if (_firebaseOn) {
      await _ensureSignedIn();
      await _firestore!.updateTask(_session!.familyId, updated);
    }
  }

  Future<void> deleteTask(String taskId) async {
    _store.deleteLocal(taskId);

    if (_firebaseOn) {
      await _ensureSignedIn();
      await _firestore!.deleteTask(_session!.familyId, taskId);
    }
  }

  Future<void> deleteMany(Set<String> ids) async {
    if (ids.isEmpty) return;

    for (final id in ids) {
      _store.deleteLocal(id);
    }

    if (_firebaseOn) {
      await _ensureSignedIn();
      await _firestore!.deleteMany(_session!.familyId, ids);
    }
  }

  Future<void> renameTask(String taskId, String newTitle) async {
    final t = _store.tasks.where((x) => x.id == taskId).cast<TaskModel?>().firstWhere((x) => x != null, orElse: () => null);
    if (t == null) return;

    final updated = t.copyWith(title: newTitle);
    _store.upsertLocal(updated);

    if (_firebaseOn) {
      await _ensureSignedIn();
      await _firestore!.updateTask(_session!.familyId, updated);
    }
  }

  Future<void> setPointsValue(String taskId, int points) async {
    final t = _store.tasks.where((x) => x.id == taskId).cast<TaskModel?>().firstWhere((x) => x != null, orElse: () => null);
    if (t == null) return;

    final updated = t.copyWith(pointsValue: points);
    _store.upsertLocal(updated);

    if (_firebaseOn) {
      await _ensureSignedIn();
      await _firestore!.updateTask(_session!.familyId, updated);
    }
  }

  Future<void> setDueDate(String taskId, DateTime? dueDate) async {
    final t = _store.tasks.where((x) => x.id == taskId).cast<TaskModel?>().firstWhere((x) => x != null, orElse: () => null);
    if (t == null) return;

    final updated = t.copyWith(dueDate: dueDate);
    _store.upsertLocal(updated);

    if (_firebaseOn) {
      await _ensureSignedIn();
      await _firestore!.updateTask(_session!.familyId, updated);
    }
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final ordered = _store.reorderLocal(oldIndex, newIndex);

    if (_firebaseOn) {
      await _ensureSignedIn();
      await _firestore!.batchUpdateOrder(_session!.familyId, ordered);
    }
  }
}
