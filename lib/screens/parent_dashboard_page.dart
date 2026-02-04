import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'login_page.dart';
import 'settings_page.dart';
import 'message_page.dart';
import 'awards_page.dart';

class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key});
  static const routeName = '/parent';

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  String? _selectedChildId;

  User get _user => FirebaseAuth.instance.currentUser!;
  String get _parentUid => _user.uid;

  DocumentReference<Map<String, dynamic>> get _parentDoc =>
      FirebaseFirestore.instance.collection('parents').doc(_parentUid);

  CollectionReference<Map<String, dynamic>> get _childrenCol =>
      _parentDoc.collection('children');

  CollectionReference<Map<String, dynamic>> _privateTasksCol(String childId) =>
      _childrenCol.doc(childId).collection('tasksPrivate');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),

      bottomNavigationBar: _ParentBottomNav(
        onTasks: () {},
        onStore: () {
          if (_selectedChildId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pick a child first 👶🏽')),
            );
            return;
          }
          Navigator.pushNamed(
            context,
            AwardsPage.routeName,
            arguments: {
              'parentUid': _parentUid,
              'childId': _selectedChildId!,
              'mode': 'parent',
            },
          );
        },
        onMessages: () {
          Navigator.pushNamed(
            context,
            MessagePage.routeName,
            arguments: {'parentUid': _parentUid},
          );
        },
        onSettings: () => Navigator.pushNamed(context, SettingsPage.routeName),
      ),

      body: SafeArea(
        child: Stack(
          children: [
            const _CuteBokehBackground(),
            Column(
              children: [
                _TopHeader(
                  title: 'Donezy',
                  onLogout: _confirmLogout,
                  onSettings: () =>
                      Navigator.pushNamed(context, SettingsPage.routeName),
                  onPhotoTap: _pickAndUploadParentPhoto,
                ),

                // Children strip
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: _ChildrenStrip(
                    childrenStream: _childrenCol
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
                    selectedChildId: _selectedChildId,
                    onSelect: (id) => setState(() => _selectedChildId = id),
                    onEditChildren: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Child manager coming next ✨'),
                        ),
                      );
                    },
                  ),
                ),

                // Main content
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _childrenCol
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final children = snap.data!.docs;

                      if (children.isEmpty) {
                        return _EmptyState(
                          title: 'Add your first child',
                          subtitle:
                              'Create a child profile so you can start making cute tasks.',
                          buttonText: 'Create Child',
                          onPressed: _createChildQuick,
                        );
                      }

                      _selectedChildId ??= children.first.id;

                      QueryDocumentSnapshot<Map<String, dynamic>> selected = children.first;

// If we have a selectedChildId, try to find it safely (no firstWhere/orElse)
final wantedId = _selectedChildId;
if (wantedId != null) {
  for (final d in children) {
    if (d.id == wantedId) {
      selected = d;
      break;
    }
  }
}

// If selectedChildId is null, lock onto the first child
_selectedChildId ??= selected.id;


                      final data = selected.data();
                      final childName = (data['name'] ?? 'Child').toString();
                      final points = (data['points'] ?? 0) is int
                          ? (data['points'] ?? 0) as int
                          : int.tryParse('${data['points']}') ?? 0;

                      return _DashboardBody(
                        childId: selected.id,
                        childName: childName,
                        childPoints: points,
                        tasksStream: _privateTasksCol(selected.id)
                            .orderBy('createdAt', descending: false)
                            .snapshots(),
                        onAddTask: () => _openCreateTaskSheet(
                          childId: selected.id,
                          childName: childName,
                        ),
                        onDeleteTask: (taskId) => _confirmDeleteTask(
                          childId: selected.id,
                          taskId: taskId,
                        ),
                        onToggleActive: (taskId, isActive) =>
                            _privateTasksCol(selected.id).doc(taskId).update({
                          'isActive': isActive,
                          'updatedAt': FieldValue.serverTimestamp(),
                        }),
                        onToggleImportant: (taskId, isImportant) =>
                            _privateTasksCol(selected.id).doc(taskId).update({
                          'isImportant': isImportant,
                          'updatedAt': FieldValue.serverTimestamp(),
                        }),
                        onMarkComplete: (taskId, pointsToAdd) async {
                          await _privateTasksCol(selected.id).doc(taskId).update({
                            'status': 'completed',
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          // add points to child
                          await _childrenCol.doc(selected.id).update({
                            'points': FieldValue.increment(pointsToAdd),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Completed! +$pointsToAdd pts 🎉')),
                          );
                        },
                        onPickDueDate: (taskId, current) async {
                          final picked = await _pickCuteDate(context, current);
                          if (picked == null) return;
                          await _privateTasksCol(selected.id).doc(taskId).update({
                            'dueDate': Timestamp.fromDate(picked),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                        },
                        onPickIcon: (taskId, iconKey) async {
                          await _privateTasksCol(selected.id).doc(taskId).update({
                            'iconKey': iconKey,
                            'imageUrl': null, // icon replaces image
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                        },
                        onPickTaskImage: (taskId) async {
                          final url = await _pickAndUploadTaskImage(
                            parentUid: _parentUid,
                            childId: selected.id,
                            taskId: taskId,
                          );
                          if (url == null) return;

                          await _privateTasksCol(selected.id).doc(taskId).update({
                            'imageUrl': url,
                            'iconKey': null, // image replaces icon
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------
  // Quick child create (simple)
  // ----------------------------
  Future<void> _createChildQuick() async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Create child',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final doc = _childrenCol.doc();
    await doc.set({
      'name': name,
      'points': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    setState(() => _selectedChildId = doc.id);
  }

  // ----------------------------
  // Logout
  // ----------------------------
  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _CuteConfirmDialog(
        title: 'Logout?',
        message: 'Are you sure you want to log out?',
        confirmText: 'Logout',
        cancelText: 'Cancel',
      ),
    );

    if (ok == true) {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      if (!context.mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        LoginPage.routeName,
        (r) => false,
      );
    }
  }

  // ----------------------------
  // Parent photo (optional)
  // ----------------------------
  Future<void> _pickAndUploadParentPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;

    final file = File(x.path);
    final ref = FirebaseStorage.instance
        .ref()
        .child('parents')
        .child(_parentUid)
        .child('avatar.jpg');

    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    await _parentDoc.set({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ----------------------------
  // Create task sheet
  // ----------------------------
  Future<void> _openCreateTaskSheet({
    required String childId,
    required String childName,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateTaskSheet(
        childName: childName,
        onCreate: (payload) async {
          final doc = _privateTasksCol(childId).doc();
          await doc.set({
            'title': payload.title,
            'points': payload.points,
            'status': 'open',
            'isActive': payload.isActive,
            'isImportant': payload.isImportant,
            'dueDate': payload.dueDate == null
                ? null
                : Timestamp.fromDate(payload.dueDate!),
            'iconKey': payload.iconKey,
            'imageUrl': payload.imageUrl,
            'note': payload.note,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        },
        uploadImage: () async {
          // Temporary upload to a "draft" path for create flow
          final picker = ImagePicker();
          final x = await picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
          );
          if (x == null) return null;

          final file = File(x.path);
          final ref = FirebaseStorage.instance
              .ref()
              .child('parents')
              .child(_parentUid)
              .child('children')
              .child(childId)
              .child('taskDrafts')
              .child('draft_${DateTime.now().millisecondsSinceEpoch}.jpg');

          await ref.putFile(file);
          return ref.getDownloadURL();
        },
      ),
    );
  }

  Future<void> _confirmDeleteTask({
    required String childId,
    required String taskId,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _CuteConfirmDialog(
        title: 'Delete task?',
        message: 'This will remove the task from the list.',
        confirmText: 'Delete',
        cancelText: 'Cancel',
      ),
    );

    if (ok == true) {
      await _privateTasksCol(childId).doc(taskId).delete();
    }
  }

  // ----------------------------
  // Due date picker
  // ----------------------------
  Future<DateTime?> _pickCuteDate(BuildContext context, DateTime? current) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
  }

  // ----------------------------
  // Task image upload
  // ----------------------------
  Future<String?> _pickAndUploadTaskImage({
    required String parentUid,
    required String childId,
    required String taskId,
  }) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return null;

    final file = File(x.path);
    final ref = FirebaseStorage.instance
        .ref()
        .child('parents')
        .child(parentUid)
        .child('children')
        .child(childId)
        .child('tasks')
        .child(taskId)
        .child('photo.jpg');

    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}

// ============================================================================
// Dashboard body (tasks list + stats)
// ============================================================================
class _DashboardBody extends StatelessWidget {
  final String childId;
  final String childName;
  final int childPoints;

  final Stream<QuerySnapshot<Map<String, dynamic>>> tasksStream;

  final VoidCallback onAddTask;
  final Future<void> Function(String taskId) onDeleteTask;

  final Future<void> Function(String taskId, bool isActive) onToggleActive;
  final Future<void> Function(String taskId, bool isImportant) onToggleImportant;
  final Future<void> Function(String taskId, int pointsToAdd) onMarkComplete;

  final Future<void> Function(String taskId, DateTime? current) onPickDueDate;
  final Future<void> Function(String taskId, String iconKey) onPickIcon;
  final Future<void> Function(String taskId) onPickTaskImage;

  const _DashboardBody({
    required this.childId,
    required this.childName,
    required this.childPoints,
    required this.tasksStream,
    required this.onAddTask,
    required this.onDeleteTask,
    required this.onToggleActive,
    required this.onToggleImportant,
    required this.onMarkComplete,
    required this.onPickDueDate,
    required this.onPickIcon,
    required this.onPickTaskImage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        children: [
          _KidSummaryCard(name: childName, points: childPoints),
          const SizedBox(height: 10),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: tasksStream,
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];

                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (docs.isEmpty) {
                  return _EmptyState(
                    title: 'No tasks yet ✨',
                    subtitle: 'Tap the button below to add a cute task.',
                    buttonText: 'Add Task',
                    onPressed: onAddTask,
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE6E8FF)),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 14,
                        color: Color(0x12000000),
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Tasks',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            _SoftButton(
                              icon: Icons.add_rounded,
                              label: 'Add',
                              onTap: onAddTask,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final d = docs[i];
                            final data = d.data();

                            final title = (data['title'] ?? 'Task').toString();
                            final note = (data['note'] ?? '').toString();
                            final points = (data['points'] ?? 0) is int
                                ? (data['points'] ?? 0) as int
                                : int.tryParse('${data['points']}') ?? 0;

                            final status = (data['status'] ?? 'open').toString();
                            final isActive = (data['isActive'] ?? true) as bool;
                            final isImportant = (data['isImportant'] ?? false) as bool;

                            final dueTs = data['dueDate'];
                            final dueDate = dueTs is Timestamp ? dueTs.toDate() : null;

                            final iconKey = (data['iconKey'] ?? '').toString();
                            final imageUrl = (data['imageUrl'] ?? '').toString();

                            return _TaskCard(
                              title: title,
                              note: note,
                              points: points,
                              status: status,
                              isActive: isActive,
                              isImportant: isImportant,
                              dueDate: dueDate,
                              iconKey: iconKey,
                              imageUrl: imageUrl.isEmpty ? null : imageUrl,
                              onDelete: () => onDeleteTask(d.id),
                              onToggleActive: (v) => onToggleActive(d.id, v),
                              onToggleImportant: (v) => onToggleImportant(d.id, v),
                              onComplete: status == 'completed'
                                  ? null
                                  : () => onMarkComplete(d.id, points),
                              onPickDue: () => onPickDueDate(d.id, dueDate),
                              onPickIcon: () => _IconPickerSheet.open(
                                context,
                                onPick: (key) => onPickIcon(d.id, key),
                              ),
                              onPickImage: () => onPickTaskImage(d.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Top header (logo + parent photo + logout/settings)
// ============================================================================
class _TopHeader extends StatelessWidget {
  final String title;
  final VoidCallback onLogout;
  final VoidCallback onSettings;
  final VoidCallback onPhotoTap;

  const _TopHeader({
    required this.title,
    required this.onLogout,
    required this.onSettings,
    required this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.logout_rounded,
            onTap: onLogout,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _CircleIconButton(
            icon: Icons.settings_rounded,
            onTap: onSettings,
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onPhotoTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE6E8FF)),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 10,
                    color: Color(0x12000000),
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.person_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE6E8FF)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              color: Color(0x12000000),
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon),
      ),
    );
  }
}

// ============================================================================
// Children strip
// ============================================================================
class _ChildrenStrip extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> childrenStream;
  final String? selectedChildId;
  final ValueChanged<String> onSelect;
  final VoidCallback onEditChildren;

  const _ChildrenStrip({
    required this.childrenStream,
    required this.selectedChildId,
    required this.onSelect,
    required this.onEditChildren,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: childrenStream,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (!snap.hasData) {
          return const SizedBox(height: 74);
        }

        return Row(
          children: [
            _SoftButton(
              icon: Icons.edit_rounded,
              label: 'Edit',
              onTap: onEditChildren,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 62,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final name = (d.data()['name'] ?? 'Kid').toString();
                    final selected = d.id == selectedChildId;

                    return InkWell(
                      onTap: () => onSelect(d.id),
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFDEE7FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE6E8FF)),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 10,
                              color: Color(0x12000000),
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SoftButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SoftButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF2FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6E8FF)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Kid summary card
// ============================================================================
class _KidSummaryCard extends StatelessWidget {
  final String name;
  final int points;

  const _KidSummaryCard({required this.name, required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6E8FF)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            color: Color(0x12000000),
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F3),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.child_care_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                const Text('Ready for some cute tasks? ✨'),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF2FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Text('Points',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '$points',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Task card
// ============================================================================
class _TaskCard extends StatelessWidget {
  final String title;
  final String note;
  final int points;
  final String status;
  final bool isActive;
  final bool isImportant;
  final DateTime? dueDate;

  final String iconKey;
  final String? imageUrl;

  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;
  final ValueChanged<bool> onToggleImportant;
  final VoidCallback? onComplete;
  final VoidCallback onPickDue;
  final VoidCallback onPickIcon;
  final VoidCallback onPickImage;

  const _TaskCard({
    required this.title,
    required this.note,
    required this.points,
    required this.status,
    required this.isActive,
    required this.isImportant,
    required this.dueDate,
    required this.iconKey,
    required this.imageUrl,
    required this.onDelete,
    required this.onToggleActive,
    required this.onToggleImportant,
    required this.onComplete,
    required this.onPickDue,
    required this.onPickIcon,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final completed = status == 'completed';
    final pillText = completed
        ? 'Completed'
        : !isActive
            ? 'Inactive'
            : 'Open';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: completed ? const Color(0xFFF1FFF6) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8FF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _TaskVisual(iconKey: iconKey, imageUrl: imageUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _Pill(text: '$points pts', subtle: true),
                        const SizedBox(width: 8),
                        _Pill(
                          text: pillText,
                          subtle: !completed,
                        ),
                        const SizedBox(width: 8),
                        if (isImportant)
                          const _Pill(
                            text: 'Important',
                            subtle: false,
                          ),
                      ],
                    ),
                    if (dueDate != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Due: ${_fmtDate(dueDate!)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),

          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(note),
            ),
          ],

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickDue,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('Due'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickIcon,
                  icon: const Icon(Icons.emoji_emotions_rounded),
                  label: const Text('Icon'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickImage,
                  icon: const Icon(Icons.image_rounded),
                  label: const Text('Photo'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  value: isActive,
                  onChanged: completed ? null : onToggleActive,
                  title: const Text('Active'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  value: isImportant,
                  onChanged: completed ? null : onToggleImportant,
                  title: const Text('Important'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),

          if (!completed)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onComplete,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Mark Completed 🎉'),
              ),
            ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}

class _TaskVisual extends StatelessWidget {
  final String iconKey;
  final String? imageUrl;

  const _TaskVisual({required this.iconKey, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2FF),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(imageUrl!, fit: BoxFit.cover)
          : Center(
              child: Text(
                _iconToEmoji(iconKey),
                style: const TextStyle(fontSize: 24),
              ),
            ),
    );
  }

  String _iconToEmoji(String key) {
    switch (key) {
      case 'bed':
        return '🛏️';
      case 'brush':
        return '🪥';
      case 'clean':
        return '🧹';
      case 'homework':
        return '📚';
      case 'trash':
        return '🗑️';
      case 'pet':
        return '🐶';
      case 'laundry':
        return '🧺';
      case 'star':
        return '⭐';
      default:
        return '✨';
    }
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool subtle;

  const _Pill({required this.text, this.subtle = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: subtle ? const Color(0xFFEFF2FF) : const Color(0xFFDEE7FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

// ============================================================================
// Create Task Sheet
// ============================================================================
class _CreateTaskPayload {
  final String title;
  final int points;
  final bool isActive;
  final bool isImportant;
  final DateTime? dueDate;
  final String? iconKey;
  final String? imageUrl;
  final String note;

  _CreateTaskPayload({
    required this.title,
    required this.points,
    required this.isActive,
    required this.isImportant,
    required this.dueDate,
    required this.iconKey,
    required this.imageUrl,
    required this.note,
  });
}

class _CreateTaskSheet extends StatefulWidget {
  final String childName;
  final Future<void> Function(_CreateTaskPayload payload) onCreate;
  final Future<String?> Function() uploadImage;

  const _CreateTaskSheet({
    required this.childName,
    required this.onCreate,
    required this.uploadImage,
  });

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController(text: '10');

  bool _active = true;
  bool _important = false;
  DateTime? _dueDate;
  String? _iconKey = 'star';
  String? _imageUrl;

  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final points = int.tryParse(_pointsCtrl.text.trim()) ?? 0;

    setState(() => _saving = true);
    try {
      await widget.onCreate(
        _CreateTaskPayload(
          title: title,
          points: points < 0 ? 0 : points,
          isActive: _active,
          isImportant: _important,
          dueDate: _dueDate,
          iconKey: _imageUrl == null ? _iconKey : null,
          imageUrl: _imageUrl,
          note: _noteCtrl.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE6E8FF)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 18,
              color: Color(0x14000000),
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE6E8FF),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'New task for ${widget.childName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Task title'),
            ),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            TextField(
              controller: _pointsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Points'),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                    title: const Text('Active'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: SwitchListTile(
                    value: _important,
                    onChanged: (v) => setState(() => _important = v),
                    title: const Text('Important'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now(),
                        firstDate: DateTime(DateTime.now().year - 1),
                        lastDate: DateTime(DateTime.now().year + 3),
                      );
                      if (d != null) setState(() => _dueDate = d);
                    },
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(_dueDate == null ? 'Pick due date' : 'Due selected'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _IconPickerSheet.open(
                        context,
                        onPick: (key) => setState(() {
                          _iconKey = key;
                          _imageUrl = null;
                        }),
                      );
                    },
                    icon: const Icon(Icons.emoji_emotions_rounded),
                    label: const Text('Pick icon'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final url = await widget.uploadImage();
                      if (url == null) return;
                      setState(() {
                        _imageUrl = url;
                        _iconKey = null;
                      });
                    },
                    icon: const Icon(Icons.image_rounded),
                    label: const Text('Add photo'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Task ✨'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Icon picker
// ============================================================================
class _IconPickerSheet {
  static void open(
    BuildContext context, {
    required ValueChanged<String> onPick,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _IconPickerContent(onPick: onPick),
    );
  }
}

class _IconPickerContent extends StatelessWidget {
  final ValueChanged<String> onPick;

  const _IconPickerContent({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('star', '⭐'),
      ('clean', '🧹'),
      ('homework', '📚'),
      ('bed', '🛏️'),
      ('brush', '🪥'),
      ('trash', '🗑️'),
      ('pet', '🐶'),
      ('laundry', '🧺'),
    ];

    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE6E8FF)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            color: Color(0x14000000),
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Pick an icon',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final it in items)
                InkWell(
                  onTap: () {
                    onPick(it.$1);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF2FF),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE6E8FF)),
                    ),
                    alignment: Alignment.center,
                    child: Text(it.$2, style: const TextStyle(fontSize: 28)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Empty state
// ============================================================================
class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE6E8FF)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 18,
              color: Color(0x14000000),
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 40),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Cute confirm dialog
// ============================================================================
class _CuteConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;

  const _CuteConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText),
        ),
      ],
    );
  }
}

// ============================================================================
// Cute background
// ============================================================================
class _CuteBokehBackground extends StatelessWidget {
  const _CuteBokehBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _BokehPainter(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFBFF),
                Color(0xFFF2F5FF),
                Color(0xFFFFF1F3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BokehPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    void circle(double x, double y, double r, Color c) {
      paint.color = c;
      canvas.drawCircle(Offset(x * size.width, y * size.height), r, paint);
    }

    circle(0.15, 0.18, 60, const Color(0x22BFD0FF));
    circle(0.86, 0.16, 70, const Color(0x22FFC6D0));
    circle(0.82, 0.55, 85, const Color(0x18B8F7D4));
    circle(0.22, 0.74, 95, const Color(0x18FFD36A));
    circle(0.58, 0.88, 80, const Color(0x14C1B6FF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// Bottom nav (Parent)
// ============================================================================
class _ParentBottomNav extends StatelessWidget {
  final VoidCallback onTasks;
  final VoidCallback onStore;
  final VoidCallback onMessages;
  final VoidCallback onSettings;

  const _ParentBottomNav({
    required this.onTasks,
    required this.onStore,
    required this.onMessages,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE6E8FF)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 18,
                color: Color(0x14000000),
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              _NavPill(
                icon: Icons.checklist_rounded,
                label: 'Tasks',
                onTap: onTasks,
                selected: true,
              ),
              const SizedBox(width: 10),
              _NavPill(
                icon: Icons.storefront_rounded,
                label: 'Store',
                onTap: onStore,
              ),
              const SizedBox(width: 10),
              _NavPill(
                icon: Icons.chat_bubble_rounded,
                label: 'Chat',
                onTap: onMessages,
              ),
              const SizedBox(width: 10),
              _NavPill(
                icon: Icons.settings_rounded,
                label: 'Settings',
                onTap: onSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  const _NavPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDEE7FF) : const Color(0xFFEFF2FF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
