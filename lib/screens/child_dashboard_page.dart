import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'message_page.dart';
import 'awards_page.dart';

class ChildDashboardPage extends StatefulWidget {
  final String parentUid;
  final String childId;

  const ChildDashboardPage({
    super.key,
    required this.parentUid,
    required this.childId,
  });

  @override
  State<ChildDashboardPage> createState() => _ChildDashboardPageState();
}

class _ChildDashboardPageState extends State<ChildDashboardPage> {
  int _tab = 0; // 0 private, 1 shared

  void _openMessages() {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(
          name: MessagePage.routeName,
          arguments: {
            'parentUid': widget.parentUid,
            'mode': 'child',
            'childId': widget.childId,
          },
        ),
        builder: (_) => const MessagePage(),
      ),
    );
  }

  void _openAwards() {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(
          name: AwardsPage.routeName,
          arguments: {
            'parentUid': widget.parentUid,
            'childId': widget.childId,
          },
        ),
        builder: (_) => const AwardsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentRef =
        FirebaseFirestore.instance.collection('parents').doc(widget.parentUid);
    final childRef = parentRef.collection('children').doc(widget.childId);

    return Scaffold(
      backgroundColor: const Color(0xFFFBF7F6),
      body: SafeArea(
        child: Stack(
          children: [
            const _CuteBokehBackground(),
            Column(
              children: [
                _ChildTopBar(
                  title: 'Donezy',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: childRef.snapshots(),
                  builder: (context, snap) {
                    final data = snap.data?.data();
                    final name = (data?['name'] ?? 'Child').toString();
                    final pts = (data?['points'] ?? 0) as num;

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      child: _ChildHeaderCard(
                        name: name,
                        points: pts.toInt(),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: _CuteCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabPill(
                            label: 'My Tasks',
                            selected: _tab == 0,
                            onTap: () => setState(() => _tab = 0),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TabPill(
                            label: 'Family Tasks',
                            selected: _tab == 1,
                            onTap: () => setState(() => _tab = 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: _tab == 0
                        ? _ChildPrivateTasks(
                            parentUid: widget.parentUid,
                            childId: widget.childId,
                          )
                        : _ChildSharedTasks(parentUid: widget.parentUid),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        onMessages: _openMessages,
        onAwards: _openAwards,
      ),
    );
  }
}

// =======================================================
// PRIVATE TASKS (Child) — ONLY ACTIVE + shows Important + icon/image + due date
// =======================================================
class _ChildPrivateTasks extends StatelessWidget {
  final String parentUid;
  final String childId;

  const _ChildPrivateTasks({required this.parentUid, required this.childId});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('parents')
        .doc(parentUid)
        .collection('children')
        .doc(childId)
        .collection('tasksPrivate');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyState(
            text: 'No tasks yet.\nAsk your parent to add some ✨',
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();

            final title = (data['title'] ?? '').toString();
            final pts = (data['points'] ?? 0) as num;
            final status = (data['status'] ?? 'open').toString();
            final isImportant = (data['isImportant'] ?? false) as bool;
            final iconKey = data['iconKey'] as String?;
            final imageUrl = data['imageUrl'] as String?;
            final dueTs = data['dueDate'] as Timestamp?;
            final dueDate = dueTs?.toDate();

            return _CuteTaskTile(
              title: title,
              points: pts.toInt(),
              status: status,
              isImportant: isImportant,
              dueDate: dueDate,
              iconKey: iconKey,
              imageUrl: imageUrl,
              trailing: _StatusSetter(
                onSetStatus: (newStatus) => d.reference.update({
                  'status': newStatus,
                  'updatedAt': FieldValue.serverTimestamp(),
                }),
              ),
            );
          },
        );
      },
    );
  }
}

// =======================================================
// SHARED TASKS (Child)
// =======================================================
class _ChildSharedTasks extends StatelessWidget {
  final String parentUid;

  const _ChildSharedTasks({required this.parentUid});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('parents')
        .doc(parentUid)
        .collection('tasksShared');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snap) {
        final allDocs = snap.data?.docs ?? [];

        final docs = allDocs.where((d) {
          final data = d.data();
          final v = data['isActive'];
          if (v is bool) return v == true;
          return true;
        }).toList();

        if (docs.isEmpty) {
          return const _EmptyState(text: 'No family tasks yet.');
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();

            final title = (data['title'] ?? '').toString();
            final pts = (data['points'] ?? 0) as num;
            final isImportant = (data['isImportant'] ?? false) as bool;
            final iconKey = data['iconKey'] as String?;
            final imageUrl = data['imageUrl'] as String?;
            final dueTs = data['dueDate'] as Timestamp?;
            final dueDate = dueTs?.toDate();

            return _CuteTaskTile(
              title: title,
              points: pts.toInt(),
              status: null,
              isImportant: isImportant,
              dueDate: dueDate,
              iconKey: iconKey,
              imageUrl: imageUrl,
              trailing: null,
            );
          },
        );
      },
    );
  }
}

// =======================================================
// Cute Task Tile
// =======================================================
class _CuteTaskTile extends StatelessWidget {
  const _CuteTaskTile({
    required this.title,
    required this.points,
    required this.status,
    required this.isImportant,
    required this.dueDate,
    required this.iconKey,
    required this.imageUrl,
    required this.trailing,
  });

  final String title;
  final int points;
  final String? status;
  final bool isImportant;
  final DateTime? dueDate;
  final String? iconKey;
  final String? imageUrl;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final icon = DonezyTaskIcons.resolve(iconKey);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE9D7D3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _TaskVisual(icon: icon, imageUrl: imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: Color(0xFF2C2C2C),
                        ),
                      ),
                    ),
                    if (isImportant) ...[
                      const SizedBox(width: 8),
                      _ImportantBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _DueDatePill(dueDate: dueDate),
                    const SizedBox(width: 10),
                    _PointsPill(points: points),
                  ],
                ),
                if (status != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Status: $status',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6E6E6E),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _TaskVisual extends StatelessWidget {
  const _TaskVisual({required this.icon, required this.imageUrl});

  final IconData icon;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9D7D3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: imageUrl != null
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(icon, color: const Color(0xFF6E6E6E)),
                )
              : Icon(icon, color: const Color(0xFF6E6E6E)),
        ),
      ),
    );
  }
}

class _DueDatePill extends StatelessWidget {
  const _DueDatePill({required this.dueDate});

  final DateTime? dueDate;

  @override
  Widget build(BuildContext context) {
    final text = dueDate == null ? 'No due date' : _formatDue(dueDate!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9D7D3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month_rounded,
              size: 18, color: Color(0xFF4C78FF)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF50607A),
            ),
          ),
        ],
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

class _PointsPill extends StatelessWidget {
  const _PointsPill({required this.points});
  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6D9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9D7D3)),
      ),
      child: Text(
        '$points pts',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF7A5A00),
        ),
      ),
    );
  }
}

class _ImportantBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE7E1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFB4A7)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.priority_high_rounded,
              size: 16, color: Color(0xFFFE7A6B)),
          SizedBox(width: 6),
          Text(
            'IMPORTANT',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: Color(0xFFFE7A6B),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSetter extends StatelessWidget {
  const _StatusSetter({required this.onSetStatus});

  final void Function(String newStatus) onSetStatus;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSetStatus,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'open', child: Text('Open')),
        PopupMenuItem(value: 'closed', child: Text('Closed')),
        PopupMenuItem(value: 'late', child: Text('Late')),
        PopupMenuItem(value: 'completed', child: Text('Completed')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE9D7D3)),
        ),
        child: const Text(
          'Set',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final VoidCallback onMessages;
  final VoidCallback onAwards;

  const _BottomNav({required this.onMessages, required this.onAwards});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onMessages,
                icon: const Icon(Icons.mail_rounded),
                label: const Text('Messages'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFE7A6B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAwards,
                icon: const Icon(Icons.emoji_events_rounded),
                label: const Text('Awards'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2C2C2C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  side: const BorderSide(color: Color(0xFFE9D7D3)),
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildTopBar extends StatelessWidget {
  const _ChildTopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          _RoundIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2C2C2C),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 54),
        ],
      ),
    );
  }
}

class _ChildHeaderCard extends StatelessWidget {
  const _ChildHeaderCard({required this.name, required this.points});

  final String name;
  final int points;

  @override
  Widget build(BuildContext context) {
    return _CuteCard(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF2FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE9D7D3)),
            ),
            child: const Icon(Icons.sentiment_satisfied_rounded, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Points: $points',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6E6E6E),
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

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFD7CF) : const Color(0xFFF7F1EF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFFFB4A7) : const Color(0xFFE9D7D3),
          ),
        ),
        child: Center(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _CuteCard extends StatelessWidget {
  final Widget child;

  const _CuteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE9D7D3)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            color: Color(0x14000000),
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
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
        side: const BorderSide(color: Color(0xFFE9D7D3)),
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

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFF6E6E6E),
        ),
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
        child: const Stack(
          children: [
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
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

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

  static IconData resolve(String? key) {
    if (key == null) return Icons.auto_awesome_rounded;
    return _map[key] ?? Icons.auto_awesome_rounded;
  }
}
