import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
      backgroundColor: const Color(0xFFFBF7F6),
      body: SafeArea(
        child: Stack(
          children: [
            const _CuteBokehBackground(),
            Column(
              children: [
                _TopHeader(
                  title: 'Donezy',
                  onLogout: _confirmLogout,
                  onSettings: () {
                    // TODO: Navigator.pushNamed(context, SettingsPage.routeName);
                  },
                  onPhotoTap: () async {
                    // Optional: parent avatar upload
                    await _pickAndUploadParentPhoto();
                  },
                ),

                // Children row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _ChildrenStrip(
                    childrenStream: _childrenCol
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
                    selectedChildId: _selectedChildId,
                    onSelect: (id) => setState(() => _selectedChildId = id),
                    onEditChildren: () {
                      // TODO: children management page
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
                          buttonText: 'Create Child (coming next)',
                          onPressed: () {},
                        );
                      }

                      // Auto-select first child if none selected
                      _selectedChildId ??= children.first.id;

                      final selected = children
                          .firstWhere((d) => d.id == _selectedChildId,
                              orElse: () => children.first);
                      final childName =
                          (selected.data()['name'] ?? 'Child').toString();
                      final points =
                          (selected.data()['points'] ?? 0) as int;

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
                        onDeleteTask: (taskId) =>
                            _confirmDeleteTask(childId: selected.id, taskId: taskId),
                        onToggleActive: (taskId, isActive) => _privateTasksCol(selected.id)
                            .doc(taskId)
                            .update({'isActive': isActive, 'updatedAt': FieldValue.serverTimestamp()}),
                        onToggleImportant: (taskId, isImportant) => _privateTasksCol(selected.id)
                            .doc(taskId)
                            .update({'isImportant': isImportant, 'updatedAt': FieldValue.serverTimestamp()}),
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
      if (!mounted) return;
      // TODO: Navigate to LoginPage
      Navigator.of(context).popUntil((r) => r.isFirst);
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
            'dueDate': payload.dueDate == null ? null : Timestamp.fromDate(payload.dueDate!),
            'iconKey': payload.iconKey,
            'imageUrl': payload.imageUrl,
            'note': payload.note,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        },
        uploadImage: () async {
          // Create a temp task doc first, upload, then delete if user cancels create (we avoid that)
          // For “create sheet”, we upload to a temp path and return a URL.
          final url = await _pickAndUploadTempTaskImage(parentUid: _parentUid, childId: childId);
          return url;
        },
      ),
    );
  }

  // ----------------------------
  // Delete task
  // ----------------------------
  Future<void> _confirmDeleteTask({required String childId, required String taskId}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _CuteConfirmDialog(
        title: 'Delete this task?',
        message: 'This will remove the task from this child’s list.',
        confirmText: 'Delete',
        cancelText: 'Cancel',
        danger: true,
      ),
    );

    if (ok == true) {
      await _privateTasksCol(childId).doc(taskId).delete();
    }
  }

  // ----------------------------
  // Date picker (cute themed)
  // ----------------------------
  Future<DateTime?> _pickCuteDate(BuildContext context, DateTime? current) async {
    final now = DateTime.now();
    final initial = current ?? DateTime(now.year, now.month, now.day);

    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFE7A6B), // coral
              onPrimary: Colors.white,
              surface: Color(0xFFFFFBFA),
              onSurface: Color(0xFF2B2B2B),
            ),
            dialogBackgroundColor: const Color(0xFFFFFBFA),
          ),
          child: child!,
        );
      },
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
        .child('task_image.jpg');

    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<String?> _pickAndUploadTempTaskImage({
    required String parentUid,
    required String childId,
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
        .child('temp')
        .child('task_${DateTime.now().millisecondsSinceEpoch}.jpg');

    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}

// =======================================================
// UI: Body
// =======================================================

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.childId,
    required this.childName,
    required this.childPoints,
    required this.tasksStream,
    required this.onAddTask,
    required this.onDeleteTask,
    required this.onToggleActive,
    required this.onToggleImportant,
    required this.onPickDueDate,
    required this.onPickIcon,
    required this.onPickTaskImage,
  });

  final String childId;
  final String childName;
  final int childPoints;

  final Stream<QuerySnapshot<Map<String, dynamic>>> tasksStream;

  final VoidCallback onAddTask;
  final void Function(String taskId) onDeleteTask;
  final void Function(String taskId, bool isActive) onToggleActive;
  final void Function(String taskId, bool isImportant) onToggleImportant;
  final Future<void> Function(String taskId, DateTime? current) onPickDueDate;
  final Future<void> Function(String taskId, String? iconKey) onPickIcon;
  final Future<void> Function(String taskId) onPickTaskImage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      child: Column(
        children: [
          _ChildSummaryCard(
            childName: childName,
            totalPoints: childPoints,
            maxAwardablePointsStream: tasksStream,
          ),
          const SizedBox(height: 10),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFE9D7D3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 54,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAD9D5),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 10),

                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: tasksStream,
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final tasks = snap.data!.docs;

                      final totalPoints = tasks.fold<int>(0, (sum, d) {
                        final data = d.data();
                        final pts = (data['points'] ?? 0) as int;
                        final isActive = (data['isActive'] ?? true) as bool;
                        return sum + (isActive ? pts : 0);
                      });

                      return Expanded(
                        child: Column(
                          children: [
                            _TasksHeader(
                              taskCount: tasks.length,
                              totalPoints: totalPoints,
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: tasks.isEmpty
                                  ? const _TasksEmptyCute()
                                  : ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                      itemCount: tasks.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                                      itemBuilder: (context, i) {
                                        final doc = tasks[i];
                                        final data = doc.data();

                                        final title = (data['title'] ?? 'Task').toString();
                                        final points = (data['points'] ?? 0) as int;
                                        final isActive = (data['isActive'] ?? true) as bool;
                                        final isImportant = (data['isImportant'] ?? false) as bool;
                                        final iconKey = data['iconKey'] as String?;
                                        final imageUrl = data['imageUrl'] as String?;
                                        final dueTs = data['dueDate'] as Timestamp?;
                                        final dueDate = dueTs?.toDate();

                                        return _CuteTaskCard(
                                          title: title,
                                          points: points,
                                          isActive: isActive,
                                          isImportant: isImportant,
                                          dueDate: dueDate,
                                          iconKey: iconKey,
                                          imageUrl: imageUrl,
                                          onDelete: () => onDeleteTask(doc.id),
                                          onToggleActive: (v) => onToggleActive(doc.id, v),
                                          onToggleImportant: (v) => onToggleImportant(doc.id, v),
                                          onTapDueDate: () => onPickDueDate(doc.id, dueDate),
                                          onTapChooseIcon: () async {
                                            final picked = await showModalBottomSheet<String?>(
                                              context: context,
                                              backgroundColor: Colors.transparent,
                                              builder: (_) => _IconPickerSheet(
                                                selectedKey: iconKey,
                                              ),
                                            );
                                            if (picked == null) return;
                                            await onPickIcon(doc.id, picked);
                                          },
                                          onTapUploadImage: () async {
                                            await onPickTaskImage(doc.id);
                                          },
                                        );
                                      },
                                    ),
                            ),

                            // Cute Add Task button
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                              child: SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF7B6A), Color(0xFFFFB86B)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x33FF7B6A),
                                        blurRadius: 16,
                                        offset: Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    onPressed: onAddTask,
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_circle_outline, color: Colors.white),
                                        SizedBox(width: 10),
                                        Text(
                                          'Add a task',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// UI: Header + Background
// =======================================================

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.title,
    required this.onLogout,
    required this.onSettings,
    required this.onPhotoTap,
  });

  final String title;
  final VoidCallback onLogout;
  final VoidCallback onSettings;
  final VoidCallback onPhotoTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        children: [
          Row(
            children: [
              _RoundIconButton(
                icon: Icons.logout_rounded,
                onTap: onLogout,
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                  color: Color(0xFF2C2C2C),
                ),
              ),
              const Spacer(),
              _RoundIconButton(
                icon: Icons.settings_rounded,
                onTap: onSettings,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _PhotoCard(onTap: onPhotoTap),
        ],
      ),
    );
  }
}

class _CuteBokehBackground extends StatelessWidget {
  const _CuteBokehBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFBFA), Color(0xFFFCEFEB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: const [
            _BokehDot(top: 90, left: 40, size: 170, color: Color(0x33FFC6B8)),
            _BokehDot(top: 180, right: 20, size: 210, color: Color(0x26FFD7A6)),
            _BokehDot(bottom: 180, left: 10, size: 220, color: Color(0x1ED3F2FF)),
            _BokehDot(bottom: 90, right: 40, size: 180, color: Color(0x1EFFC6B8)),
          ],
        ),
      ),
    );
  }
}

class _BokehDot extends StatelessWidget {
  const _BokehDot({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.color,
  });

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.75),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEAD9D5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 54,
          height: 54,
          child: Icon(icon, color: const Color(0xFF6E6E6E)),
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.white.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: Color(0xFFEAD9D5)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: SizedBox(
            width: 240,
            height: 170,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F1F1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.image_outlined, size: 34, color: Color(0xFF7B7B7B)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2EF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEAD9D5)),
                  ),
                  child: const Text(
                    'Tap to add picture',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6E6E6E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =======================================================
// Children strip
// =======================================================

class _ChildrenStrip extends StatelessWidget {
  const _ChildrenStrip({
    required this.childrenStream,
    required this.selectedChildId,
    required this.onSelect,
    required this.onEditChildren,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> childrenStream;
  final String? selectedChildId;
  final void Function(String childId) onSelect;
  final VoidCallback onEditChildren;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: childrenStream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(height: 54, child: Center(child: CircularProgressIndicator()));
        }

        final docs = snap.data!.docs;

        return Row(
          children: [
            _RoundIconButton(icon: Icons.edit_rounded, onTap: onEditChildren),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: docs.map((d) {
                    final name = (d.data()['name'] ?? 'Child').toString();
                    final selected = d.id == selectedChildId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _ChildChip(
                        label: name,
                        selected: selected,
                        onTap: () => onSelect(d.id),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChildChip extends StatelessWidget {
  const _ChildChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFFFD7CF) : Colors.white.withOpacity(0.9);
    final border = selected ? const Color(0xFFFFB4A7) : const Color(0xFFEAD9D5);
    final textColor = selected ? const Color(0xFF2C2C2C) : const Color(0xFF6E6E6E);

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w900, color: textColor, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

// =======================================================
// Summary card
// =======================================================

class _ChildSummaryCard extends StatelessWidget {
  const _ChildSummaryCard({
    required this.childName,
    required this.totalPoints,
    required this.maxAwardablePointsStream,
  });

  final String childName;
  final int totalPoints;
  final Stream<QuerySnapshot<Map<String, dynamic>>> maxAwardablePointsStream;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFEAD9D5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            childName,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  icon: Icons.star_rounded,
                  iconBg: const Color(0xFFFFF1CC),
                  label: 'Total points',
                  value: '$totalPoints',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: maxAwardablePointsStream,
                  builder: (context, snap) {
                    int maxPts = 0;
                    if (snap.hasData) {
                      for (final d in snap.data!.docs) {
                        final data = d.data();
                        final isActive = (data['isActive'] ?? true) as bool;
                        final pts = (data['points'] ?? 0) as int;
                        if (isActive) maxPts += pts;
                      }
                    }
                    return _StatPill(
                      icon: Icons.card_giftcard_rounded,
                      iconBg: const Color(0xFFFFE3DE),
                      label: 'Max awardable',
                      value: '$maxPts',
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconBg;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEAD9D5)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEAD9D5)),
            ),
            child: Icon(icon, color: const Color(0xFF6E6E6E)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6E6E6E))),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// Tasks header
// =======================================================

class _TasksHeader extends StatelessWidget {
  const _TasksHeader({required this.taskCount, required this.totalPoints});
  final int taskCount;
  final int totalPoints;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE7E1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEAD9D5)),
            ),
            child: const Icon(Icons.list_alt_rounded, color: Color(0xFF6E6E6E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Color(0xFF2C2C2C)),
                children: [
                  const TextSpan(
                    text: 'Tasks',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  TextSpan(
                    text: '  •  $taskCount',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF6E6E6E)),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2EF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEAD9D5)),
            ),
            child: Text(
              '$totalPoints pts',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF6E6E6E)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TasksEmptyCute extends StatelessWidget {
  const _TasksEmptyCute();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE7E1),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFEAD9D5)),
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 34, color: Color(0xFF6E6E6E)),
            ),
            const SizedBox(height: 12),
            const Text(
              'No tasks yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap “Add a task” to create something cute.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6E6E6E), fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// Task card (matches screenshot vibe)
// =======================================================

class _CuteTaskCard extends StatelessWidget {
  const _CuteTaskCard({
    required this.title,
    required this.points,
    required this.isActive,
    required this.isImportant,
    required this.dueDate,
    required this.iconKey,
    required this.imageUrl,
    required this.onDelete,
    required this.onToggleActive,
    required this.onToggleImportant,
    required this.onTapDueDate,
    required this.onTapChooseIcon,
    required this.onTapUploadImage,
  });

  final String title;
  final int points;

  final bool isActive;
  final bool isImportant;
  final DateTime? dueDate;

  final String? iconKey;
  final String? imageUrl;

  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;
  final ValueChanged<bool> onToggleImportant;
  final VoidCallback onTapDueDate;
  final VoidCallback onTapChooseIcon;
  final VoidCallback onTapUploadImage;

  @override
  Widget build(BuildContext context) {
    final icon = DonezyTaskIcons.resolve(iconKey);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFEAD9D5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                // Drag handle visual (doesn't reorder yet)
                _MiniSquare(
                  child: const Icon(Icons.drag_handle_rounded, color: Color(0xFF6E6E6E)),
                  onTap: () {},
                ),
                const SizedBox(width: 10),

                // Icon/Image tile
                _TaskVisualTile(
                  icon: icon,
                  imageUrl: imageUrl,
                  onTapIcon: onTapChooseIcon,
                  onTapImage: onTapUploadImage,
                ),

                const SizedBox(width: 12),

                // Title + due date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      _DueDatePill(
                        dueDate: dueDate,
                        onTap: onTapDueDate,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Delete
                _MiniSquare(
                  bg: const Color(0xFFFFE0E0),
                  child: const Icon(Icons.delete_rounded, color: Color(0xFFE44C4C)),
                  onTap: onDelete,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Bottom pills row like screenshot
            Row(
              children: [
                Expanded(
                  child: _ActionPill(
                    icon: Icons.edit_rounded,
                    text: 'Title',
                    bg: const Color(0xFFFFF1ED),
                    onTap: () {
                      // TODO: implement edit title
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionPill(
                    icon: Icons.star_rounded,
                    text: '$points pts',
                    bg: const Color(0xFFFFF6D9),
                    onTap: () {
                      // TODO: implement edit points
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionPill(
                    icon: Icons.notes_rounded,
                    text: 'Note',
                    bg: const Color(0xFFEFF3FF),
                    onTap: () {
                      // TODO: implement edit note
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Open + enable switch + important + mark done placeholder
            Row(
              children: [
                Expanded(
                  child: _StatusPill(
                    icon: Icons.lock_open_rounded,
                    text: 'Open',
                    bg: const Color(0xFFF1FFF3),
                    border: const Color(0xFFD9F0DD),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TogglePill(
                    icon: Icons.toggle_on_rounded,
                    text: isActive ? 'Enabled' : 'Disabled',
                    value: isActive,
                    onChanged: onToggleActive,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _ImportantPill(
                    value: isImportant,
                    onChanged: onToggleImportant,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MarkDonePill(
                    onTap: () {
                      // TODO: implement mark done
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
}

class _MiniSquare extends StatelessWidget {
  const _MiniSquare({
    required this.child,
    required this.onTap,
    this.bg,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg ?? const Color(0xFFF7F1EF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFEAD9D5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(width: 56, height: 56, child: Center(child: child)),
      ),
    );
  }
}

class _TaskVisualTile extends StatelessWidget {
  const _TaskVisualTile({
    required this.icon,
    required this.imageUrl,
    required this.onTapIcon,
    required this.onTapImage,
  });

  final IconData icon;
  final String? imageUrl;
  final VoidCallback onTapIcon;
  final VoidCallback onTapImage;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF4D6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFEAD9D5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: imageUrl == null ? onTapIcon : onTapImage,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(icon, color: const Color(0xFF6E6E6E)),
                    )
                  : Icon(icon, color: const Color(0xFF6E6E6E)),
            ),
          ),
        ),
      ),
    );
  }
}

class _DueDatePill extends StatelessWidget {
  const _DueDatePill({required this.dueDate, required this.onTap});
  final DateTime? dueDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = dueDate == null ? 'Pick a date' : _formatDue(dueDate!);

    return Material(
      color: const Color(0xFFEFF3FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEAD9D5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF4C78FF)),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF50607A)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDue(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dd = DateTime(d.year, d.month, d.day);

    if (dd == today) return 'Today';
    if (dd == today.add(const Duration(days: 1))) return 'Tomorrow';
    return '${d.month}/${d.day}/${d.year}';
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.text,
    required this.bg,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEAD9D5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF6E6E6E)),
              const SizedBox(width: 8),
              Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.text,
    required this.bg,
    required this.border,
  });

  final IconData icon;
  final String text;
  final Color bg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF3F7A52)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3F7A52))),
        ],
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.icon,
    required this.text,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String text;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAD9D5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4C78FF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF50607A)),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF4C78FF),
          ),
        ],
      ),
    );
  }
}

class _ImportantPill extends StatelessWidget {
  const _ImportantPill({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value ? const Color(0xFFFFE7E1) : const Color(0xFFFFF3F0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEAD9D5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                value ? Icons.priority_high_rounded : Icons.priority_high_outlined,
                color: const Color(0xFFFE7A6B),
              ),
              const SizedBox(width: 8),
              Text(
                value ? 'Important' : 'Not important',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFE7A6B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkDonePill extends StatelessWidget {
  const _MarkDonePill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF6D9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEAD9D5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.check_circle_outline_rounded, color: Color(0xFFB07A00)),
              SizedBox(width: 8),
              Text('Mark done', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFB07A00))),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================
// Icon system: 20+ cute choices
// =======================================================

class DonezyTaskIcons {
  static const Map<String, IconData> _map = {
    'sparkle': Icons.auto_awesome_rounded,
    'broom': Icons.cleaning_services_rounded,
    'laundry': Icons.local_laundry_service_rounded,
    'trash': Icons.delete_outline_rounded,
    'bed': Icons.bed_rounded,
    'book': Icons.menu_book_rounded,
    'homework': Icons.edit_note_rounded,
    'pet': Icons.pets_rounded,
    'dishes': Icons.local_dining_rounded,
    'teeth': Icons.emoji_people_rounded,
    'shower': Icons.shower_rounded,
    'food': Icons.restaurant_rounded,
    'water': Icons.water_drop_rounded,
    'walk': Icons.directions_walk_rounded,
    'school': Icons.school_rounded,
    'music': Icons.music_note_rounded,
    'game': Icons.sports_esports_rounded,
    'toy': Icons.toys_rounded,
    'car': Icons.directions_car_rounded,
    'heart': Icons.favorite_rounded,
    'star': Icons.star_rounded,
    'timer': Icons.timer_rounded,
  };

  static List<String> get keys => _map.keys.toList();

  static IconData resolve(String? key) {
    if (key == null) return Icons.auto_awesome_rounded; // default cute icon
    return _map[key] ?? Icons.auto_awesome_rounded;
  }

  static String prettyName(String key) {
    switch (key) {
      case 'sparkle':
        return 'Sparkle';
      case 'broom':
        return 'Cleaning';
      case 'laundry':
        return 'Laundry';
      case 'trash':
        return 'Trash';
      case 'bed':
        return 'Bedtime';
      case 'book':
        return 'Reading';
      case 'homework':
        return 'Homework';
      case 'pet':
        return 'Pets';
      case 'dishes':
        return 'Dishes';
      case 'teeth':
        return 'Brush Teeth';
      case 'shower':
        return 'Shower';
      case 'food':
        return 'Meal';
      case 'water':
        return 'Water';
      case 'walk':
        return 'Walk';
      case 'school':
        return 'School';
      case 'music':
        return 'Music';
      case 'game':
        return 'Gaming';
      case 'toy':
        return 'Tidy Toys';
      case 'car':
        return 'Ride';
      case 'heart':
        return 'Kindness';
      case 'star':
        return 'Star';
      case 'timer':
        return 'Timer';
      default:
        return key;
    }
  }
}

class _IconPickerSheet extends StatelessWidget {
  const _IconPickerSheet({required this.selectedKey});
  final String? selectedKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFA),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFEAD9D5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 54, height: 6, decoration: BoxDecoration(color: const Color(0xFFEAD9D5), borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 12),
          const Text('Pick an icon', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: DonezyTaskIcons.keys.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, i) {
              final key = DonezyTaskIcons.keys[i];
              final selected = key == selectedKey;

              return Material(
                color: selected ? const Color(0xFFFFD7CF) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: selected ? const Color(0xFFFFB4A7) : const Color(0xFFEAD9D5)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.pop(context, key),
                  child: Icon(DonezyTaskIcons.resolve(key), color: const Color(0xFF6E6E6E)),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                side: const BorderSide(color: Color(0xFFEAD9D5)),
              ),
              onPressed: () => Navigator.pop(context, selectedKey),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// Create Task bottom sheet
// =======================================================

class _CreateTaskPayload {
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

  final String title;
  final int points;
  final bool isActive;
  final bool isImportant;
  final DateTime? dueDate;
  final String? iconKey;
  final String? imageUrl;
  final String? note;
}

class _CreateTaskSheet extends StatefulWidget {
  const _CreateTaskSheet({
    required this.childName,
    required this.onCreate,
    required this.uploadImage,
  });

  final String childName;
  final Future<void> Function(_CreateTaskPayload payload) onCreate;
  final Future<String?> Function() uploadImage;

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController(text: '10');
  final _noteCtrl = TextEditingController();

  bool _active = true;
  bool _important = false;
  DateTime? _dueDate;

  String? _iconKey = 'sparkle';
  String? _imageUrl;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _pointsCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBFA),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFEAD9D5)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 54, height: 6, decoration: BoxDecoration(color: const Color(0xFFEAD9D5), borderRadius: BorderRadius.circular(99))),
              const SizedBox(height: 12),
              Text('New task for ${widget.childName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),

              _Field(
                label: 'Title',
                child: TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Fold and put away laundry',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'Points',
                      child: TextField(
                        controller: _pointsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: InputBorder.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Field(
                      label: 'Due date',
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate ?? DateTime.now(),
                            firstDate: DateTime(DateTime.now().year - 1),
                            lastDate: DateTime(DateTime.now().year + 5),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFFFE7A6B),
                                  onPrimary: Colors.white,
                                  surface: Color(0xFFFFFBFA),
                                  onSurface: Color(0xFF2B2B2B),
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked == null) return;
                          setState(() => _dueDate = picked);
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: Color(0xFF4C78FF)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _dueDate == null
                                    ? 'Pick date'
                                    : '${_dueDate!.month}/${_dueDate!.day}/${_dueDate!.year}',
                                style: const TextStyle(fontWeight: FontWeight.w900),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              _Field(
                label: 'Visual',
                child: Row(
                  children: [
                    Expanded(
                      child: _miniAction(
                        icon: Icons.emoji_emotions_rounded,
                        text: 'Pick icon',
                        onTap: () async {
                          final picked = await showModalBottomSheet<String?>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (_) => _IconPickerSheet(selectedKey: _iconKey),
                          );
                          if (picked == null) return;
                          setState(() {
                            _iconKey = picked;
                            _imageUrl = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _miniAction(
                        icon: Icons.image_rounded,
                        text: 'Upload image',
                        onTap: () async {
                          final url = await widget.uploadImage();
                          if (url == null) return;
                          setState(() {
                            _imageUrl = url;
                            _iconKey = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              _Field(
                label: 'Options',
                child: Row(
                  children: [
                    Expanded(
                      child: _toggleChip(
                        icon: Icons.priority_high_rounded,
                        text: _important ? 'Important' : 'Not important',
                        active: _important,
                        onTap: () => setState(() => _important = !_important),
                        activeColor: const Color(0xFFFE7A6B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _toggleChip(
                        icon: Icons.toggle_on_rounded,
                        text: _active ? 'Enabled' : 'Disabled',
                        active: _active,
                        onTap: () => setState(() => _active = !_active),
                        activeColor: const Color(0xFF4C78FF),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              _Field(
                label: 'Note (optional)',
                child: TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Anything extra for this task?',
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 10),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                ),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7B6A), Color(0xFFFFB86B)],
                    ),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _saving ? null : _create,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Create task', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    side: const BorderSide(color: Color(0xFFEAD9D5)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniAction({required IconData icon, required String text, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEAD9D5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF6E6E6E)),
              const SizedBox(width: 8),
              Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleChip({
    required IconData icon,
    required String text,
    required bool active,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return Material(
      color: active ? activeColor.withOpacity(0.12) : const Color(0xFFF7F7FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFEAD9D5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: activeColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(fontWeight: FontWeight.w900, color: activeColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final title = _titleCtrl.text.trim();
      final points = int.tryParse(_pointsCtrl.text.trim()) ?? 0;
      final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

      if (title.isEmpty) throw Exception('Please enter a title.');

      await widget.onCreate(
        _CreateTaskPayload(
          title: title,
          points: points,
          isActive: _active,
          isImportant: _important,
          dueDate: _dueDate,
          iconKey: _iconKey,
          imageUrl: _imageUrl,
          note: note,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAD9D5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6E6E6E))),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

// =======================================================
// Dialogs + Empty State
// =======================================================

class _CuteConfirmDialog extends StatelessWidget {
  const _CuteConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    this.danger = false,
  });

  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final confirmColor = danger ? const Color(0xFFE44C4C) : const Color(0xFFFE7A6B);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: const Color(0xFFFFFBFA),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6E6E6E))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFEAD9D5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6E6E6E), fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFE7A6B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: onPressed,
                  child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
