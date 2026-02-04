import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum AwardsMode { parent, child }

class AwardsPage extends StatelessWidget {
  static const routeName = '/awards';

  final String parentUid;
  final String childId;
  final AwardsMode mode;

  const AwardsPage({
    super.key,
    required this.parentUid,
    required this.childId,
    this.mode = AwardsMode.parent,
  });

  @override
  Widget build(BuildContext context) {
    final childRef = FirebaseFirestore.instance
        .collection('parents')
        .doc(parentUid)
        .collection('children')
        .doc(childId);

    final awardsRef = childRef.collection('awards');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: Text(mode == AwardsMode.parent ? 'Store (Awards)' : 'Awards'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: childRef.snapshots(),
          builder: (context, childSnap) {
            final childData = childSnap.data?.data() ?? {};
            final childName = (childData['name'] ?? 'Kid').toString();
            final points = (childData['points'] ?? 0) is int
                ? (childData['points'] ?? 0) as int
                : int.tryParse('${childData['points']}') ?? 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderPill(
                  title: mode == AwardsMode.parent
                      ? 'Store for $childName'
                      : 'Hey $childName!',
                  subtitle: mode == AwardsMode.parent
                      ? 'Add prizes, set point costs, and make rewards feel magical ✨'
                      : 'You have $points points. Scroll and claim what you can!',
                  points: points,
                  showPoints: mode == AwardsMode.child,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: awardsRef
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Text(
                            mode == AwardsMode.parent
                                ? 'No awards yet ✨\nTap + to add one.'
                                : 'No awards yet ✨',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final d = docs[i];
                          final data = d.data();

                          final title = (data['title'] ?? 'Award').toString();
                          final note = (data['note'] ?? '').toString();
                          final cost = (data['cost'] ?? 0) is int
                              ? (data['cost'] ?? 0) as int
                              : int.tryParse('${data['cost']}') ?? 0;
                          final isActive = (data['isActive'] ?? true) as bool;
                          final redeemedAt = data['redeemedAt'];

                          final isRedeemed = redeemedAt != null;

                          // ✅ Child rule: Claim button is only visible if enough points + active + not redeemed
                          final canClaim =
                              !isRedeemed && isActive && points >= cost && cost > 0;

                          // ✅ Child rule: hide inactive awards completely (kid shouldn’t see them)
                          if (mode == AwardsMode.child && !isActive) {
                            return const SizedBox.shrink();
                          }

                          return _AwardCard(
                            title: title,
                            note: note,
                            cost: cost,
                            isActive: isActive,
                            isRedeemed: isRedeemed,
                            mode: mode,
                            canClaim: canClaim,
                            onClaim: () => _claimAward(
                              context,
                              childRef: childRef,
                              awardRef: d.reference,
                              cost: cost,
                            ),
                            onEdit: () => _openEditAward(
                              context,
                              awardRef: d.reference,
                              initialTitle: title,
                              initialNote: note,
                              initialCost: cost,
                            ),
                            onToggleActive: (v) =>
                                d.reference.update({'isActive': v}),
                            onDelete: () => _confirmDelete(context,
                                onDelete: () => d.reference.delete()),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),

      // ✅ Parent-only add button
      floatingActionButton: mode == AwardsMode.parent
          ? FloatingActionButton(
              onPressed: () => _openNewAward(context, awardsRef: awardsRef),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _openNewAward(
    BuildContext context, {
    required CollectionReference<Map<String, dynamic>> awardsRef,
  }) async {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final costCtrl = TextEditingController(text: '50');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _AwardDialog(
        title: 'New award',
        titleCtrl: titleCtrl,
        noteCtrl: noteCtrl,
        costCtrl: costCtrl,
        confirmText: 'Save',
      ),
    );

    if (ok == true) {
      final title = titleCtrl.text.trim();
      final note = noteCtrl.text.trim();
      final cost = int.tryParse(costCtrl.text.trim()) ?? 0;
      if (title.isEmpty) return;

      await awardsRef.add({
        'title': title,
        'note': note,
        'cost': cost < 0 ? 0 : cost,
        'isActive': true,
        'redeemedAt': null,
        'redeemedBy': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _openEditAward(
    BuildContext context, {
    required DocumentReference<Map<String, dynamic>> awardRef,
    required String initialTitle,
    required String initialNote,
    required int initialCost,
  }) async {
    final titleCtrl = TextEditingController(text: initialTitle);
    final noteCtrl = TextEditingController(text: initialNote);
    final costCtrl = TextEditingController(text: initialCost.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _AwardDialog(
        title: 'Edit award',
        titleCtrl: titleCtrl,
        noteCtrl: noteCtrl,
        costCtrl: costCtrl,
        confirmText: 'Update',
      ),
    );

    if (ok == true) {
      final title = titleCtrl.text.trim();
      final note = noteCtrl.text.trim();
      final cost = int.tryParse(costCtrl.text.trim()) ?? 0;
      if (title.isEmpty) return;

      await awardRef.update({
        'title': title,
        'note': note,
        'cost': cost < 0 ? 0 : cost,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _confirmDelete(
    BuildContext context, {
    required Future<void> Function() onDelete,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Delete award?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('This will remove the award from the list.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await onDelete();
  }

  Future<void> _claimAward(
    BuildContext context, {
    required DocumentReference<Map<String, dynamic>> childRef,
    required DocumentReference<Map<String, dynamic>> awardRef,
    required int cost,
  }) async {
    if (cost <= 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Claim this award?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('This costs $cost points.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not yet')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Claim')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      // ✅ Transaction: deduct points + mark award redeemed (safe)
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final childSnap = await tx.get(childRef);
        final awardSnap = await tx.get(awardRef);

        final child = childSnap.data() ?? {};
        final award = awardSnap.data() ?? {};

        final points = (child['points'] ?? 0) is int
            ? (child['points'] ?? 0) as int
            : int.tryParse('${child['points']}') ?? 0;

        final redeemedAt = award['redeemedAt'];
        final isActive = (award['isActive'] ?? true) as bool;

        if (!isActive) throw Exception('This award is not available right now.');
        if (redeemedAt != null) throw Exception('This award was already redeemed.');
        if (points < cost) throw Exception('Not enough points.');

        tx.update(childRef, {
          'points': points - cost,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.update(awardRef, {
          'redeemedAt': FieldValue.serverTimestamp(),
          'redeemedBy': childRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Redeemed! 🎉 Tell your parent to deliver the prize.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }
}

class _HeaderPill extends StatelessWidget {
  final String title;
  final String subtitle;
  final int points;
  final bool showPoints;

  const _HeaderPill({
    required this.title,
    required this.subtitle,
    required this.points,
    required this.showPoints,
  });

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(subtitle),
              ],
            ),
          ),
          if (showPoints)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF2FF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  const Text('Points',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('$points',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AwardCard extends StatelessWidget {
  final String title;
  final String note;
  final int cost;
  final bool isActive;
  final bool isRedeemed;
  final AwardsMode mode;
  final bool canClaim;

  final VoidCallback onClaim;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDelete;

  const _AwardCard({
    required this.title,
    required this.note,
    required this.cost,
    required this.isActive,
    required this.isRedeemed,
    required this.mode,
    required this.canClaim,
    required this.onClaim,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pill = _Pill(
      text: isRedeemed
          ? 'Redeemed'
          : isActive
              ? 'Available'
              : 'Hidden',
      subtle: !isRedeemed && !isActive,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8FF)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Color(0x12000000),
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900)),
              ),
              pill,
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Pill(text: '$cost pts', subtle: true),
              const SizedBox(width: 8),
              if (mode == AwardsMode.parent)
                Switch(
                  value: isActive,
                  onChanged: isRedeemed ? null : onToggleActive,
                ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(note),
          ],
          const SizedBox(height: 10),
          if (mode == AwardsMode.child)
            if (canClaim)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onClaim,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Text('Claim'),
                ),
              )
            else
              const SizedBox.shrink(),
          if (mode == AwardsMode.parent)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
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

class _AwardDialog extends StatelessWidget {
  final String title;
  final TextEditingController titleCtrl;
  final TextEditingController noteCtrl;
  final TextEditingController costCtrl;
  final String confirmText;

  const _AwardDialog({
    required this.title,
    required this.titleCtrl,
    required this.noteCtrl,
    required this.costCtrl,
    required this.confirmText,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          TextField(
            controller: costCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cost (points)'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText)),
      ],
    );
  }
}
