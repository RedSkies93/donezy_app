import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/global_reward_inbox.dart';

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
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  String? _selectedChildId;

  User get _user => _auth.currentUser!;

  CollectionReference<Map<String, dynamic>> get _childrenCol =>
      _db.collection('parents').doc(_user.uid).collection('children');

  CollectionReference<Map<String, dynamic>> _privateTasksCol(String childId) =>
      _childrenCol.doc(childId).collection('tasksPrivate');

  CollectionReference<Map<String, dynamic>> get _parentMeta =>
      _db.collection('parents').doc(_user.uid).collection('meta');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      bottomNavigationBar: _ParentBottomNav(
        onTasks: () {},
        onMessages: _openMessages,
        onAwards: _openAwards,
        onAddTask: _openAddTaskForSelectedChild,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _TopHeader(
              onLogout: _confirmLogout,
              onSettings: _openSettings,
              onPickPhoto: _pickParentPhoto,
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    _childrenCol.orderBy('createdAt', descending: false).snapshots(),
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

                  QueryDocumentSnapshot<Map<String, dynamic>> selected =
                      children.first;
                  final wanted = _selectedChildId;
                  if (wanted != null) {
                    for (final d in children) {
                      if (d.id == wanted) {
                        selected = d;
                        break;
                      }
                    }
                  }
                  _selectedChildId = selected.id;

                  final childName =
                      (selected.data()['name'] ?? 'Child').toString();
                  final pointsRaw = selected.data()['points'] ?? 0;
                  final childPoints = pointsRaw is int
                      ? pointsRaw
                      : int.tryParse('$pointsRaw') ?? 0;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    child: Column(
                      children: [
                        // ✅ Global inbox for reward approvals across all kids
                        GlobalRewardInbox(parentUid: _user.uid),

                        _ChildSelector(
                          children: children,
                          selectedChildId: _selectedChildId!,
                          onSelectChild: (id) =>
                              setState(() => _selectedChildId = id),
                          onAddChild: _createChildQuick,
                        ),
                        const SizedBox(height: 10),

                        _KidSummaryCard(name: childName, points: childPoints),
                        const SizedBox(height: 10),

                        Expanded(
                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _privateTasksCol(selected.id)
                                .orderBy('createdAt', descending: false)
                                .snapshots(),
                            builder: (context, taskSnap) {
                              if (!taskSnap.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              final docs = taskSnap.data!.docs;

                              if (docs.isEmpty) {
                                return _EmptyState(
                                  title: 'No tasks yet ✨',
                                  subtitle: 'Tap Add Task to create your first one.',
                                  buttonText: 'Add Task',
                                  onPressed: () => _openCreateTaskSheet(
                                    childId: selected.id,
                                    childName: childName,
                                  ),
                                );
                              }

                              final pending =
                                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                              final other =
                                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                              for (final d in docs) {
                                final status =
                                    (d.data()['status'] ?? 'open').toString();
                                if (status == 'pending') {
                                  pending.add(d);
                                } else {
                                  other.add(d);
                                }
                              }

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border:
                                      Border.all(color: const Color(0xFFE6E8FF)),
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
                                      padding:
                                          const EdgeInsets.fromLTRB(14, 12, 14, 10),
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
                                            onTap: () => _openCreateTaskSheet(
                                              childId: selected.id,
                                              childName: childName,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    Expanded(
                                      child: ListView(
                                        physics: const BouncingScrollPhysics(),
                                        padding:
                                            const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                        children: [
                                          if (pending.isNotEmpty) ...[
                                            _SectionHeader(
                                              title: 'Needs Review ✨',
                                              subtitle: '${pending.length} waiting',
                                              tint: const Color(0xFFFF7AA2),
                                            ),
                                            const SizedBox(height: 10),
                                            ...pending.map((d) => _buildTaskCard(
                                                  childId: selected.id,
                                                  taskDoc: d,
                                                  showApproveReject: true,
                                                )),
                                            const SizedBox(height: 8),
                                          ],
                                          if (other.isNotEmpty) ...[
                                            _SectionHeader(
                                              title: 'All Tasks',
                                              subtitle: '${other.length} total',
                                              tint: const Color(0xFF17C9B2),
                                            ),
                                            const SizedBox(height: 10),
                                            ...other.map((d) => _buildTaskCard(
                                                  childId: selected.id,
                                                  taskDoc: d,
                                                  showApproveReject: false,
                                                )),
                                          ],
                                        ],
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard({
    required String childId,
    required QueryDocumentSnapshot<Map<String, dynamic>> taskDoc,
    required bool showApproveReject,
  }) {
    final data = taskDoc.data();
    final title = (data['title'] ?? 'Task').toString();
    final note = (data['note'] ?? '').toString();
    final pointsRaw = data['points'] ?? 0;
    final points = pointsRaw is int ? pointsRaw : int.tryParse('$pointsRaw') ?? 0;

    final status = (data['status'] ?? 'open').toString();
    final isActive = (data['isActive'] ?? true) as bool;
    final isImportant = (data['isImportant'] ?? false) as bool;

    final dueTs = data['dueDate'];
    final dueDate = dueTs is Timestamp ? dueTs.toDate() : null;

    final iconKey = (data['iconKey'] ?? 'sparkle').toString();
    final imageUrl = (data['imageUrl'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _TaskCard(
        title: title,
        note: note,
        points: points,
        status: status,
        isActive: isActive,
        isImportant: isImportant,
        dueDate: dueDate,
        iconKey: iconKey,
        imageUrl: imageUrl.isEmpty ? null : imageUrl,
        onDelete: () => _confirmDeleteTask(childId: childId, taskId: taskDoc.id),
        onToggleActive: (v) => _privateTasksCol(childId).doc(taskDoc.id).update({
          'isActive': v,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        onToggleImportant: (v) => _privateTasksCol(childId).doc(taskDoc.id).update({
          'isImportant': v,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        onPickDue: () => _pickDueDate(childId, taskDoc.id, dueDate),
        onPickIcon: () => _IconPickerSheet.open(
          context,
          onPick: (key) => _privateTasksCol(childId).doc(taskDoc.id).update({
            'iconKey': key,
            'updatedAt': FieldValue.serverTimestamp(),
          }),
        ),
        onPickImage: () => _pickTaskImage(childId, taskDoc.id),
        onApprove:
            showApproveReject ? () => _approvePending(childId, taskDoc.id, points) : null,
        onReject: showApproveReject ? () => _rejectPending(childId, taskDoc.id) : null,
      ),
    );
  }

  Future<void> _approvePending(String childId, String taskId, int pointsToAdd) async {
    await _privateTasksCol(childId).doc(taskId).update({
      'status': 'completed',
      'isActive': false,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _childrenCol.doc(childId).update({
      'points': FieldValue.increment(pointsToAdd),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Approved! +$pointsToAdd pts ✨')),
    );
  }

  Future<void> _rejectPending(String childId, String taskId) async {
    await _privateTasksCol(childId).doc(taskId).update({
      'status': 'open',
      'isActive': true,
      'rejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sent back to Open 🫧')),
    );
  }

  Future<void> _pickDueDate(String childId, String taskId, DateTime? current) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;

    await _privateTasksCol(childId).doc(taskId).update({
      'dueDate': Timestamp.fromDate(picked),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _pickTaskImage(String childId, String taskId) async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final ref = _storage
        .ref()
        .child('parents')
        .child(_user.uid)
        .child('children')
        .child(childId)
        .child('tasks')
        .child('$taskId.jpg');

    await ref.putFile(File(picked.path));
    final url = await ref.getDownloadURL();

    await _privateTasksCol(childId).doc(taskId).update({
      'imageUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _openSettings() => Navigator.pushNamed(context, SettingsPage.routeName);

  void _openMessages() {
    Navigator.pushNamed(context, MessagePage.routeName, arguments: {
      'parentUid': _user.uid,
      'mode': 'parent',
    });
  }

  void _openAwards() {
    Navigator.pushNamed(context, AwardsPage.routeName, arguments: {
      'parentUid': _user.uid,
      'mode': 'parent',
    });
  }

  void _openAddTaskForSelectedChild() async {
    if (_selectedChildId == null) return;
    final snap = await _childrenCol.doc(_selectedChildId).get();
    final name = (snap.data()?['name'] ?? 'Child').toString();
    _openCreateTaskSheet(childId: _selectedChildId!, childName: name);
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDialog(
        title: 'Logout?',
        message: 'Do you want to log out of Donezy?',
        confirmText: 'Logout',
        cancelText: 'Stay',
      ),
    );

    if (ok == true) {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, LoginPage.routeName, (_) => false);
    }
  }

  Future<void> _pickParentPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final ref = _storage.ref().child('parents').child(_user.uid).child('parent_photo.jpg');
    await ref.putFile(File(picked.path));
    final url = await ref.getDownloadURL();

    await _parentMeta.doc('profile').set({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _createChildQuick() async {
    final nameCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _TextEntryDialog(
        title: 'New Child ✨',
        hint: 'Child name',
        controller: nameCtrl,
        confirmText: 'Create',
      ),
    );

    if (ok != true) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final doc = await _childrenCol.add({
      'name': name,
      'points': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    setState(() => _selectedChildId = doc.id);
  }

  Future<void> _confirmDeleteTask({required String childId, required String taskId}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDialog(
        title: 'Delete task?',
        message: 'This task will be removed forever.',
        confirmText: 'Delete',
        cancelText: 'Cancel',
      ),
    );

    if (ok == true) {
      await _privateTasksCol(childId).doc(taskId).delete();
    }
  }

  void _openCreateTaskSheet({required String childId, required String childName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateTaskSheet(
        childName: childName,
        onCreate: (title, note, points, isImportant) async {
          await _privateTasksCol(childId).add({
            'title': title,
            'note': note,
            'points': points,
            'status': 'open',
            'isActive': true,
            'isImportant': isImportant,
            'iconKey': 'sparkle',
            'imageUrl': '',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        },
      ),
    );
  }
}

// ============================================================================
// UI Pieces
// ============================================================================
class _TopHeader extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onSettings;
  final VoidCallback onPickPhoto;

  const _TopHeader({
    required this.onLogout,
    required this.onSettings,
    required this.onPickPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          _CircleIconButton(icon: Icons.logout_rounded, onTap: onLogout),
          Expanded(
            child: Column(
              children: [
                const Text('Donezy ✨',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onPickPhoto,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF7AA2),
                          Color(0xFFFFC84A),
                          Color(0xFF17C9B2)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.photo_camera_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          _CircleIconButton(icon: Icons.settings_rounded, onTap: onSettings),
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
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _ChildSelector extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> children;
  final String selectedChildId;
  final ValueChanged<String> onSelectChild;
  final VoidCallback onAddChild;

  const _ChildSelector({
    required this.children,
    required this.selectedChildId,
    required this.onSelectChild,
    required this.onAddChild,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemCount: children.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final d = children[i];
                final name = (d.data()['name'] ?? 'Child').toString();
                final selected = d.id == selectedChildId;

                return InkWell(
                  onTap: () => onSelectChild(d.id),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFDEE7FF) : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE6E8FF)),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: selected
                            ? Colors.black.withOpacity(0.85)
                            : Colors.black.withOpacity(0.70),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onAddChild,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE6E8FF)),
              ),
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _KidSummaryCard extends StatelessWidget {
  final String name;
  final int points;
  const _KidSummaryCard({required this.name, required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [Color(0xFFFFF0C8), Color(0xFFBFF6E9)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.face_rounded, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$points pts ✨',
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color tint;

  const _SectionHeader(
      {required this.title, required this.subtitle, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint.withOpacity(0.22),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15.5)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withOpacity(0.60))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
  final VoidCallback onPickDue;
  final VoidCallback onPickIcon;
  final VoidCallback onPickImage;

  final VoidCallback? onApprove;
  final VoidCallback? onReject;

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
    required this.onPickDue,
    required this.onPickIcon,
    required this.onPickImage,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final completed = status == 'completed';
    final pending = status == 'pending';

    final pillText = completed
        ? 'Completed'
        : pending
            ? 'Needs Review'
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
                        _Pill(text: pillText, subtle: !(completed || pending)),
                        const SizedBox(width: 8),
                        if (isImportant)
                          const _Pill(text: 'Important', subtle: false),
                      ],
                    ),
                    if (dueDate != null) ...[
                      const SizedBox(height: 6),
                      Text('Due: ${_fmtDate(dueDate!)}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
              ),
              IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded)),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: Text(note)),
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
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                  onChanged: (completed || pending) ? null : onToggleActive,
                  title: const Text('Active'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  value: isImportant,
                  onChanged: (completed || pending) ? null : onToggleImportant,
                  title: const Text('Important'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          if (pending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text('Reject 🫧'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text('Approve ✨'),
                  ),
                ),
              ],
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
          : Center(child: Icon(_iconForKey(iconKey), size: 26)),
    );
  }

  static IconData _iconForKey(String key) {
    switch (key) {
      case 'star':
        return Icons.star_rounded;
      case 'dish':
        return Icons.restaurant_rounded;
      case 'laundry':
        return Icons.local_laundry_service_rounded;
      case 'toys':
        return Icons.toys_rounded;
      case 'sparkle':
      default:
        return Icons.auto_awesome_rounded;
    }
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool subtle;
  const _Pill({required this.text, required this.subtle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: subtle ? const Color(0xFFEFF2FF) : const Color(0xFFFFE0EA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }
}

class _ParentBottomNav extends StatelessWidget {
  final VoidCallback onTasks;
  final VoidCallback onMessages;
  final VoidCallback onAwards;
  final VoidCallback onAddTask;

  const _ParentBottomNav({
    required this.onTasks,
    required this.onMessages,
    required this.onAwards,
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE6E8FF)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Row(
          children: [
            Expanded(
                child:
                    _NavBubble(icon: Icons.checklist_rounded, label: 'Tasks', onTap: onTasks)),
            Expanded(child: _BigAddButton(onTap: onAddTask)),
            Expanded(
                child: _NavBubble(
                    icon: Icons.chat_bubble_rounded, label: 'Messages', onTap: onMessages)),
            Expanded(
                child: _NavBubble(
                    icon: Icons.emoji_events_rounded, label: 'Awards', onTap: onAwards)),
          ],
        ),
      ),
    );
  }
}

class _NavBubble extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavBubble({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7AA2), Color(0xFFFFC84A), Color(0xFF17C9B2)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black.withOpacity(0.70),
                fontSize: 12.5,
              )),
        ],
      ),
    );
  }
}

class _BigAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BigAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [Color(0xFF17C9B2), Color(0xFFFFC84A)]),
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Center(
          child: Text('+ Add Task',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _CreateTaskSheet extends StatefulWidget {
  final String childName;
  final Future<void> Function(String title, String note, int points, bool important)
      onCreate;

  const _CreateTaskSheet({required this.childName, required this.onCreate});

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _points = TextEditingController(text: '5');
  bool _important = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New Task for ${widget.childName} ✨',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Task title')),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)')),
            TextField(
              controller: _points,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Points'),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              value: _important,
              onChanged: (v) => setState(() => _important = v),
              title: const Text('Important'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final t = _title.text.trim();
                  if (t.isEmpty) return;
                  final p = int.tryParse(_points.text.trim()) ?? 0;
                  await widget.onCreate(t, _note.text.trim(), p, _important);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: const Text('Create Task 🎀'),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _IconPickerSheet extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _IconPickerSheet({required this.onPick});

  static void open(BuildContext context, {required ValueChanged<String> onPick}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      builder: (_) => _IconPickerSheet(onPick: onPick),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = const [
      ('sparkle', Icons.auto_awesome_rounded),
      ('star', Icons.star_rounded),
      ('dish', Icons.restaurant_rounded),
      ('laundry', Icons.local_laundry_service_rounded),
      ('toys', Icons.toys_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Pick an icon ✨',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: options.map((e) {
              return InkWell(
                onTap: () {
                  onPick(e.$1);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                      color: const Color(0xFFEFF2FF),
                      borderRadius: BorderRadius.circular(18)),
                  child: Icon(e.$2, size: 30),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SoftButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SoftButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: const Color(0xFFEFF2FF),
            borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancelText)),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmText)),
      ],
    );
  }
}

class _TextEntryDialog extends StatelessWidget {
  final String title;
  final String hint;
  final TextEditingController controller;
  final String confirmText;

  const _TextEntryDialog({
    required this.title,
    required this.hint,
    required this.controller,
    required this.confirmText,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmText)),
      ],
    );
  }
}

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
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_rounded, size: 52, color: Color(0xFFB9D7FF)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ),
      ),
    );
  }
}
