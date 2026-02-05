import 'dart:io';
import 'dart:ui';

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

const _kBackgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFFFFF3E9),
    Color(0xFFF8F2FF),
    Color(0xFFF3FBFF),
  ],
);

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
  bool _deleteMode = false;
  final Set<String> _selectedTaskIds = {};

  User get _user => _auth.currentUser!;

  CollectionReference<Map<String, dynamic>> get _childrenCol =>
      _db.collection('parents').doc(_user.uid).collection('children');

  CollectionReference<Map<String, dynamic>> _privateTasksCol(String childId) =>
      _childrenCol.doc(childId).collection('tasksPrivate');

  CollectionReference<Map<String, dynamic>> get _parentMeta =>
      _db.collection('parents').doc(_user.uid).collection('meta');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1C1A22),
              Color(0xFF24212B),
              Color(0xFF1E222D),
            ],
          )
        : _kBackgroundGradient;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1B22) : const Color(0xFFFFF7F2),
      bottomNavigationBar: _ParentBottomNav(
        onTasks: () {},
        onMessages: _openMessages,
        onAwards: _openAwards,
        onAddTask: _openAddTaskForSelectedChild,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: Stack(
          children: [
            const _PastelBackdrop(),
            SafeArea(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    _childrenCol.orderBy('createdAt', descending: false).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return Column(
                      children: [
                        _TopHeader(
                          onLogout: _confirmLogout,
                          onSettings: _openSettings,
                          onPickPhoto: _pickParentPhoto,
                          childName: 'Your Family',
                          points: 0,
                        ),
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                    );
                  }

                  final children = snap.data!.docs;

                  if (children.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                      child: Column(
                        children: [
                          _TopHeader(
                            onLogout: _confirmLogout,
                            onSettings: _openSettings,
                            onPickPhoto: _pickParentPhoto,
                            childName: 'Your Family',
                            points: 0,
                          ),
                          const SizedBox(height: 12),
                          _ChildSelector(
                            children: children,
                            selectedChildId: null,
                            onSelectChild: (_) {},
                            onAddChild: _createChildQuick,
                            onSelectFamily: _showFamilyTasks,
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _EmptyState(
                              title: 'Add your first child',
                              subtitle:
                                  'Create a child profile so you can start making cute tasks.',
                              buttonText: 'Create Child',
                              onPressed: _createChildQuick,
                            ),
                          ),
                        ],
                      ),
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
                  final childPoints =
                      pointsRaw is int ? pointsRaw : int.tryParse('$pointsRaw') ?? 0;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                    child: Column(
                      children: [
                        _TopHeader(
                          onLogout: _confirmLogout,
                          onSettings: _openSettings,
                          onPickPhoto: _pickParentPhoto,
                          childName: childName,
                          points: childPoints,
                        ),
                        const SizedBox(height: 12),
                        _ChildSelector(
                          children: children,
                          selectedChildId: _selectedChildId,
                          onSelectChild: (id) => setState(() {
                            _selectedChildId = id;
                            _deleteMode = false;
                            _selectedTaskIds.clear();
                          }),
                          onAddChild: _createChildQuick,
                          onSelectFamily: _showFamilyTasks,
                        ),
                        const SizedBox(height: 12),
                        // ✅ Global inbox for reward approvals across all kids
                        GlobalRewardInbox(parentUid: _user.uid),
                        const SizedBox(height: 10),
                        Expanded(
                          child:
                              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                                  subtitle:
                                      'Tap Add Task to create your first one.',
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

                              return Column(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF2A2632)
                                            : const Color(0xFFFFFBF7),
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF3A3341)
                                              : const Color(0xFFFFE1D4),
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            blurRadius: 18,
                                            color: Color(0x1AD5A6A6),
                                            offset: Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: ListView(
                                        physics: const BouncingScrollPhysics(),
                                        padding: const EdgeInsets.fromLTRB(
                                            12, 12, 12, 12),
                                        children: [
                                          if (pending.isNotEmpty) ...[
                                            _SectionHeader(
                                              title: 'Needs Review ✨',
                                              subtitle: '${pending.length} waiting',
                                              tint: const Color(0xFFFF9ABA),
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
                                              tint: const Color(0xFF5AD3C5),
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
                                  ),
                                  const SizedBox(height: 12),
                                  _BulkActionsBar(
                                    deleteMode: _deleteMode,
                                    selectedCount: _selectedTaskIds.length,
                                    onToggleDeleteMode: _toggleDeleteMode,
                                    onDeleteSelected: () =>
                                        _confirmBulkDelete(childId: selected.id),
                                  ),
                                ],
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
        showSelection: _deleteMode,
        isSelected: _selectedTaskIds.contains(taskDoc.id),
        onToggleSelected: _deleteMode
            ? () => setState(() {
                  if (_selectedTaskIds.contains(taskDoc.id)) {
                    _selectedTaskIds.remove(taskDoc.id);
                  } else {
                    _selectedTaskIds.add(taskDoc.id);
                  }
                })
            : null,
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

  void _toggleDeleteMode() {
    setState(() {
      _deleteMode = !_deleteMode;
      if (!_deleteMode) {
        _selectedTaskIds.clear();
      }
    });
  }

  Future<void> _confirmBulkDelete({required String childId}) async {
    if (_selectedTaskIds.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _RuledConfirmDialog(
        title: 'Delete selected tasks?',
        message:
            'These ${_selectedTaskIds.length} tasks will be removed forever.',
        confirmText: 'Delete',
        cancelText: 'Keep',
      ),
    );

    if (ok == true) {
      for (final id in _selectedTaskIds) {
        await _privateTasksCol(childId).doc(id).delete();
      }
      if (!mounted) return;
      setState(() {
        _selectedTaskIds.clear();
        _deleteMode = false;
      });
    }
  }

  void _showFamilyTasks() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Family tasks view is coming soon! 🌟')),
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
class _PastelBackdrop extends StatelessWidget {
  const _PastelBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: const [
          Positioned(
            top: -70,
            left: -60,
            child: _SoftBlob(size: 190, color: Color(0x66FFB4C9)),
          ),
          Positioned(
            top: 90,
            right: -80,
            child: _SoftBlob(size: 220, color: Color(0x66FFDC9B)),
          ),
          Positioned(
            bottom: 70,
            left: -90,
            child: _SoftBlob(size: 240, color: Color(0x668CEBD7)),
          ),
          Positioned(
            bottom: -120,
            right: -80,
            child: _SoftBlob(size: 260, color: Color(0x669CCBFF)),
          ),
        ],
      ),
    );
  }
}

class _SoftBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _SoftBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              blurRadius: 36,
              color: Color(0x22FFFFFF),
              offset: Offset(0, 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onSettings;
  final VoidCallback onPickPhoto;
  final String childName;
  final int points;

  const _TopHeader({
    required this.onLogout,
    required this.onSettings,
    required this.onPickPhoto,
    required this.childName,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF2A2632) : const Color(0xFFFFFBF7);
    final borderColor =
        isDark ? const Color(0xFF3A3341) : const Color(0xFFFFE1D4);
    final headlineColor =
        isDark ? Colors.white : const Color(0xFF4B3F4E);
    final subColor =
        isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(
              blurRadius: 18,
              color: Color(0x1AD5A6A6),
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _CircleIconButton(icon: Icons.logout_rounded, onTap: onLogout),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Donezy ✨',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: headlineColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Parent dashboard',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: subColor)),
                    ],
                  ),
                ),
                _CircleIconButton(
                  icon: Icons.settings_rounded,
                  onTap: onSettings,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: onPickPhoto,
                  child: const _IllustrationBadge(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Child’s Tasks',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: headlineColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        childName,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: headlineColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sweet, playful chores with gentle reminders.',
                        style: TextStyle(fontWeight: FontWeight.w700, color: subColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _TotalPointsPill(points: points),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IllustrationBadge extends StatelessWidget {
  const _IllustrationBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE1F0), Color(0xFFFFF2D8), Color(0xFFE0FFF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x33FFFFFF)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            color: Color(0x1AEBB0A4),
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: const [
          Positioned.fill(
            child: Icon(
              Icons.favorite_rounded,
              size: 44,
              color: Color(0x55FF9ABA),
            ),
          ),
          Positioned(
            left: 10,
            top: 12,
            child: _MiniAvatar(
              icon: Icons.person_rounded,
              color: Color(0xFFFFC07A),
            ),
          ),
          Positioned(
            right: 10,
            top: 12,
            child: _MiniAvatar(
              icon: Icons.child_care_rounded,
              color: Color(0xFF8CEBD7),
            ),
          ),
          Positioned(
            left: 22,
            bottom: 8,
            child: Icon(
              Icons.checklist_rounded,
              size: 24,
              color: Color(0xFF4C3C42),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2F2A36) : const Color(0xFFFFFBF7);
    final border = isDark ? const Color(0xFF3A3341) : const Color(0xFFF1D8CB);
    final iconColor = isDark ? Colors.white : const Color(0xFF4C3C42);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              color: Color(0x14D8B5AE),
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor),
      ),
    );
  }
}

class _ChildSelector extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> children;
  final String? selectedChildId;
  final ValueChanged<String> onSelectChild;
  final VoidCallback onAddChild;
  final VoidCallback onSelectFamily;

  const _ChildSelector({
    required this.children,
    required this.selectedChildId,
    required this.onSelectChild,
    required this.onAddChild,
    required this.onSelectFamily,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 62,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemCount: children.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                if (i == children.length) {
                  return InkWell(
                    onTap: onSelectFamily,
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE6F4FF), Color(0xFFFBE7FF)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFCCE8FF)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.groups_rounded,
                              size: 18, color: Color(0xFF4C3C42)),
                          SizedBox(width: 6),
                          Text(
                            'Family Tasks',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4C3C42),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final d = children[i];
                final name = (d.data()['name'] ?? 'Child').toString();
                final selected = selectedChildId != null && d.id == selectedChildId;

                return InkWell(
                  onTap: () => onSelectChild(d.id),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFFFE3D6)
                          : const Color(0xFFFFFBF7),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFFFC8B4)
                            : const Color(0xFFF1D8CB),
                      ),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: selected
                            ? const Color(0xFF4C3C42)
                            : const Color(0xFF6E5C64),
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
                color: isDark ? const Color(0xFF2F2A36) : const Color(0xFFFFFBF7),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? const Color(0xFF3A3341) : const Color(0xFFF1D8CB),
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                color: isDark ? Colors.white : const Color(0xFF4C3C42),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _MiniAvatar({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 16, color: const Color(0xFF4C3C42)),
    );
  }
}

class _TotalPointsPill extends StatelessWidget {
  final int points;
  const _TotalPointsPill({required this.points});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark
        ? const LinearGradient(colors: [Color(0xFF7BDFF2), Color(0xFFA5B8FF)])
        : const LinearGradient(colors: [Color(0xFFFFB56A), Color(0xFFFF9ABA)]);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Color(0x22FFB56A),
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Total $points pts',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.add_rounded,
              size: 18,
              color: Colors.white,
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: tint.withValues(alpha: 0.12),
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                    color: isDark ? Colors.white : const Color(0xFF2B2B2B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? Colors.white70
                        : Colors.black.withValues(alpha: 0.60),
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

class _BulkActionsBar extends StatelessWidget {
  final bool deleteMode;
  final int selectedCount;
  final VoidCallback onToggleDeleteMode;
  final VoidCallback onDeleteSelected;

  const _BulkActionsBar({
    required this.deleteMode,
    required this.selectedCount,
    required this.onToggleDeleteMode,
    required this.onDeleteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2A2632) : const Color(0xFFFFF7F2);
    final border = isDark ? const Color(0xFF3A3341) : const Color(0xFFFFE1D4);
    final textColor = isDark ? Colors.white : const Color(0xFF4C3C42);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Color(0x1AD5A6A6),
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onToggleDeleteMode,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: deleteMode
                    ? const LinearGradient(
                        colors: [Color(0xFFFFC7D9), Color(0xFFFFE3B0)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFEFF2FF), Color(0xFFFFF1E5)],
                      ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: deleteMode
                      ? const Color(0xFFFFB4C9)
                      : const Color(0xFFE1D7F3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    deleteMode ? Icons.delete_rounded : Icons.delete_outline_rounded,
                    size: 18,
                    color: textColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    deleteMode ? 'Delete Mode' : 'Delete Mode',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (deleteMode) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3A3341) : const Color(0xFFFFFBF7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Text(
                '$selectedCount selected',
                style: TextStyle(fontWeight: FontWeight.w900, color: textColor),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: selectedCount > 0 ? onDeleteSelected : null,
              borderRadius: BorderRadius.circular(16),
              child: Opacity(
                opacity: selectedCount > 0 ? 1 : 0.45,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9ABA), Color(0xFFFFB56A)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Delete Selected',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
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
  final bool showSelection;
  final bool isSelected;
  final VoidCallback? onToggleSelected;

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
    required this.showSelection,
    required this.isSelected,
    required this.onToggleSelected,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completed = status == 'completed';
    final pending = status == 'pending';
    final disabledToggles = completed || pending;

    final statusLabel = completed
        ? 'Completed'
        : pending
            ? 'Needs Review'
            : !isActive
                ? 'Paused'
                : 'Open';

    final statusTint = completed
        ? const Color(0xFF5AD3C5)
        : pending
            ? const Color(0xFFFF9ABA)
            : !isActive
                ? const Color(0xFFBFA7C6)
                : const Color(0xFFFFC07A);

    final cardColor = completed
        ? (isDark ? const Color(0xFF203029) : const Color(0xFFF0FFF6))
        : (isDark ? const Color(0xFF2E2935) : const Color(0xFFFFF9F4));
    final borderColor =
        isDark ? const Color(0xFF3A3341) : const Color(0xFFF1D8CB);
    final titleColor = isDark ? Colors.white : Colors.black.withValues(alpha: 0.80);
    final noteColor =
        isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.55);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Color(0x14D8B5AE),
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TaskVisual(iconKey: iconKey, imageUrl: imageUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PointsPill(
                          points: points,
                          completed: completed,
                        ),
                        if (showSelection) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: onToggleSelected,
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF8CEBD7)
                                    : (isDark
                                        ? const Color(0xFF3A3341)
                                        : const Color(0xFFFFF3EC)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF6FDCC9)
                                      : borderColor,
                                ),
                              ),
                              child: Icon(
                                isSelected
                                    ? Icons.check_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 18,
                                color: isSelected
                                    ? const Color(0xFF2B4D44)
                                    : (isDark ? Colors.white70 : titleColor),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        note,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: noteColor,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ActionChip(
                          icon: isImportant
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          label: isImportant ? 'Added!' : 'Add Important',
                          tint: const Color(0xFFFFD88B),
                          onTap: disabledToggles
                              ? null
                              : () => onToggleImportant(!isImportant),
                        ),
                        _ActionChip(
                          icon: Icons.calendar_month_rounded,
                          label: dueDate == null
                              ? 'Select Date'
                              : _fmtPrettyDate(dueDate!),
                          tint: const Color(0xFFEFF2FF),
                          trailing: Icons.keyboard_arrow_down_rounded,
                          onTap: onPickDue,
                        ),
                        _StatusChip(
                          text: statusLabel,
                          tint: statusTint,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  _HeartToggle(
                    value: isActive,
                    onChanged:
                        disabledToggles ? null : (v) => onToggleActive(v),
                  ),
                  const SizedBox(height: 8),
                  _TaskMenuButton(
                    onPickIcon: onPickIcon,
                    onPickImage: onPickImage,
                    onDelete: onDelete,
                  ),
                ],
              ),
            ],
          ),
          if (pending)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6E5C64),
                      side: const BorderSide(color: Color(0xFFF1D8CB)),
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
                      backgroundColor: const Color(0xFFFFB56A),
                      foregroundColor: Colors.white,
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text('Approve ✨'),
                  ),
                ),
              ],
              ),
            ),
        ],
      ),
    );
  }

  static String _fmtPrettyDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);

    String prefix;
    if (target == today) {
      prefix = 'Today';
    } else if (target == today.add(const Duration(days: 1))) {
      prefix = 'Tomorrow';
    } else if (target == today.subtract(const Duration(days: 1))) {
      prefix = 'Yesterday';
    } else {
      prefix = _kWeekdays[d.weekday - 1];
    }

    return '$prefix, ${_kMonths[d.month - 1]} ${d.day}';
  }

  static const _kMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const _kWeekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
}

class _PointsPill extends StatelessWidget {
  final int points;
  final bool completed;
  const _PointsPill({required this.points, required this.completed});

  @override
  Widget build(BuildContext context) {
    final colors = completed
        ? const [Color(0xFF8CEBD7), Color(0xFF5AD3C5)]
        : const [Color(0xFFFFB56A), Color(0xFFFF9ABA)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            color: Color(0x1AFFB56A),
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        '+$points pts',
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color tint;
  const _StatusChip({required this.text, required this.tint});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.70),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;
  final IconData? trailing;
  final VoidCallback? onTap;
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = enabled
        ? (isDark ? Colors.white : const Color(0xFF4C3C42))
        : (isDark ? Colors.white54 : const Color(0xFF8B7A82));

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: isDark ? 0.18 : 0.22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tint.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: fg,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                Icon(trailing, size: 18, color: fg.withValues(alpha: 0.75)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class _HeartToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _HeartToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final bgOn = const Color(0xFF8CEBD7);
    final bgOff = const Color(0xFFE7DADF);
    final track = value ? bgOn : bgOff;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 58,
          height: 34,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: track,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                blurRadius: 12,
                color: Color(0x1A000000),
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment:
                      value ? Alignment.centerLeft : Alignment.centerRight,
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: value ? 0.55 : 0.35),
                  ),
                ),
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    value
                        ? Icons.check_rounded
                        : Icons.close_rounded,
                    size: 16,
                    color: const Color(0xFF4C3C42),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TaskMenuAction { icon, photo, delete }

class _TaskMenuButton extends StatelessWidget {
  final VoidCallback onPickIcon;
  final VoidCallback onPickImage;
  final VoidCallback onDelete;
  const _TaskMenuButton({
    required this.onPickIcon,
    required this.onPickImage,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<_TaskMenuAction>(
      tooltip: 'More',
      onSelected: (v) {
        switch (v) {
          case _TaskMenuAction.icon:
            onPickIcon();
            break;
          case _TaskMenuAction.photo:
            onPickImage();
            break;
          case _TaskMenuAction.delete:
            onDelete();
            break;
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _TaskMenuAction.icon,
          child: Row(
            children: [
              Icon(Icons.emoji_emotions_rounded),
              SizedBox(width: 10),
              Text('Change icon'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _TaskMenuAction.photo,
          child: Row(
            children: [
              Icon(Icons.image_rounded),
              SizedBox(width: 10),
              Text('Add photo'),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _TaskMenuAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded),
              SizedBox(width: 10),
              Text('Delete'),
            ],
          ),
        ),
      ],
      child: Container(
        width: 40,
        height: 34,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2F2A36) : const Color(0xFFFFFBF7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF3A3341) : const Color(0xFFF1D8CB),
          ),
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          color: isDark ? Colors.white : const Color(0xFF4C3C42),
        ),
      ),
    );
  }
}

class _TaskVisual extends StatelessWidget {
  final String iconKey;
  final String? imageUrl;
  const _TaskVisual({required this.iconKey, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0x663B3550), Color(0x66536B7A), Color(0x665C7A6E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0x66FFB4C9), Color(0x66FFDC9B), Color(0x668CEBD7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x33FFFFFF)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            color: Color(0x14D8B5AE),
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(imageUrl!, fit: BoxFit.cover)
          : Center(
              child: Icon(
                _iconForKey(iconKey),
                size: 26,
                color: const Color(0xFF4C3C42),
              ),
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF26212C) : const Color(0xFFFFFBF7),
          border: Border.all(
            color: isDark ? const Color(0xFF3A3341) : const Color(0xFFF1D8CB),
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 14,
              color: Color(0x12D8B5AE),
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
                child:
                    _NavBubble(icon: Icons.checklist_rounded, label: 'Tasks', onTap: onTasks)),
            Expanded(child: _BigAddButton(onTap: onAddTask)),
            Expanded(
                child: _NavBubble(
                    icon: Icons.chat_bubble_rounded,
                    label: 'Messages',
                    onTap: onMessages,
                    showBadge: true,
                    badgeText: '•')),
            Expanded(
                child: _NavBubble(
                    icon: Icons.emoji_events_rounded,
                    label: 'Awards',
                    onTap: onAwards,
                    glow: true)),
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
  final bool showBadge;
  final String badgeText;
  final bool glow;

  const _NavBubble({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showBadge = false,
    this.badgeText = '',
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFB4C9),
                      Color(0xFFFFD88B),
                      Color(0xFF8CEBD7)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: glow
                      ? const [
                          BoxShadow(
                            blurRadius: 16,
                            color: Color(0x55FFC86F),
                            offset: Offset(0, 6),
                          ),
                        ]
                      : const [],
                ),
                child: Icon(icon, color: Colors.white),
              ),
              if (showBadge)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B9A),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: isDark ? const Color(0xFF26212C) : Colors.white,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.70),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [Color(0xFF8CEBD7), Color(0xFFFFC07A)]),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              blurRadius: 16,
              color: Color(0x338CEBD7),
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '+ Add New Task',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
              shadows: isDark
                  ? const [
                      Shadow(color: Color(0x55000000), blurRadius: 6),
                    ]
                  : null,
            ),
          ),
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
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFF1D8CB)),
    );

    InputDecoration decor({
      required String label,
      required IconData icon,
      String? hint,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF6E5C64)),
        filled: true,
        fillColor: const Color(0xFFFFF3EC),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xFFFFB56A), width: 2),
        ),
      );
    }

    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFBF7), Color(0xFFFFF2EA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFF1D8CB)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 18,
              color: Color(0x1AD5A6A6),
              offset: Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'New Task for ${widget.childName} ✨',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBF7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF1D8CB)),
                    ),
                    child: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: decor(
                label: 'Task name',
                icon: Icons.edit_rounded,
                hint: 'e.g. Fold and put away laundry',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: decor(
                label: 'Note (optional)',
                icon: Icons.sticky_note_2_rounded,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _points,
              keyboardType: TextInputType.number,
              decoration: decor(
                label: 'Points',
                icon: Icons.auto_awesome_rounded,
                hint: '5',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: _ActionChip(
                icon: _important
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                label: _important ? 'Important' : 'Add Important',
                tint: const Color(0xFFFFD88B),
                onTap: () => setState(() => _important = !_important),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: InkWell(
                onTap: () async {
                  final t = _title.text.trim();
                  if (t.isEmpty) return;
                  final p = int.tryParse(_points.text.trim()) ?? 0;
                  await widget.onCreate(t, _note.text.trim(), p, _important);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8CEBD7), Color(0xFFFFB56A)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 14,
                        color: Color(0x1A8CEBD7),
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '+ Add New Task',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),
                  ),
                ),
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

class _RuledConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;

  const _RuledConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paperColor =
        isDark ? const Color(0xFF2A2632) : const Color(0xFFFFFBF7);
    final borderColor =
        isDark ? const Color(0xFF3A3341) : const Color(0xFFFFE1D4);
    final textColor = isDark ? Colors.white : const Color(0xFF4C3C42);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            CustomPaint(
              painter: _RuledPaperPainter(
                lineColor: isDark
                    ? const Color(0xFF3A3341)
                    : const Color(0xFFEADBD3),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: paperColor,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: textColor.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(cancelText),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFB56A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(confirmText),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuledPaperPainter extends CustomPainter {
  final Color lineColor;
  const _RuledPaperPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    const spacing = 22.0;
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RuledPaperPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2632) : const Color(0xFFFFFBF7),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isDark ? const Color(0xFF3A3341) : const Color(0xFFF1D8CB),
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 16,
              color: Color(0x1AD8B5AE),
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_rounded,
              size: 56,
              color: isDark ? const Color(0xFFBFA7C6) : const Color(0xFFBFA7C6),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF4C3C42),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF6E5C64),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB56A),
                foregroundColor: Colors.white,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
