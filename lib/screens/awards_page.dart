import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AwardsPage extends StatefulWidget {
  const AwardsPage({super.key});
  static const routeName = '/awards';

  @override
  State<AwardsPage> createState() => _AwardsPageState();
}

class _AwardsPageState extends State<AwardsPage> {
  late final String parentUid;
  late final String mode; // parent | child
  String? childId;

  CollectionReference<Map<String, dynamic>> get _rewards =>
      FirebaseFirestore.instance
          .collection('parents')
          .doc(parentUid)
          .collection('rewards');

  DocumentReference<Map<String, dynamic>> get _childDoc =>
      FirebaseFirestore.instance
          .collection('parents')
          .doc(parentUid)
          .collection('children')
          .doc(childId);

  CollectionReference<Map<String, dynamic>> get _claims =>
      _childDoc.collection('rewardClaims');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    parentUid = (args['parentUid'] ?? '').toString();
    mode = (args['mode'] ?? 'parent').toString();
    childId = args['childId']?.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isChild = mode == 'child';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: Text(isChild ? 'My Rewards 🎁' : 'Rewards 🏆'),
        centerTitle: true,
        actions: [
          if (!isChild)
            IconButton(
              icon: const Icon(Icons.add_circle_rounded),
              onPressed: _openCreateReward,
            ),
        ],
      ),
      body: Column(
        children: [
          if (isChild) _ChildHeader(parentUid: parentUid, childId: childId!),
          Expanded(
            child: isChild
                ? StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _childDoc.snapshots(),
                    builder: (context, childSnap) {
                      final childData = childSnap.data?.data() ?? {};
                      final raw = childData['points'] ?? 0;
                      final childPoints =
                          raw is int ? raw : int.tryParse('$raw') ?? 0;
                      return _RewardsList(
                        parentUid: parentUid,
                        mode: mode,
                        childId: childId,
                        childPoints: childPoints,
                        rewards: _rewards,
                        claims: _claims,
                        openEditReward: _openEditReward,
                        requestClaim: _requestClaim,
                      );
                    },
                  )
                : _RewardsList(
                    parentUid: parentUid,
                    mode: mode,
                    childId: childId,
                    childPoints: 0,
                    rewards: _rewards,
                    claims: _claims,
                    openEditReward: _openEditReward,
                    requestClaim: _requestClaim,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestClaim(String rewardId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDialog(
        title: 'Request this reward?',
        message: 'This will ask your parent for approval 🎁',
        confirmText: 'Request',
        cancelText: 'Cancel',
      ),
    );
    if (ok != true) return;

    await _claims.add({
      'rewardId': rewardId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Requested! 🎁')),
    );
  }

  Future<void> _openCreateReward() async {
    final titleCtrl = TextEditingController();
    final ptsCtrl = TextEditingController(text: '50');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _RewardDialog(
        title: 'New Reward ✨',
        titleCtrl: titleCtrl,
        pointsCtrl: ptsCtrl,
        enabled: true,
        confirmText: 'Create',
      ),
    );

    if (ok != true) return;

    final title = titleCtrl.text.trim();
    final points = int.tryParse(ptsCtrl.text.trim()) ?? 0;
    if (title.isEmpty) return;

    await _rewards.add({
      'title': title,
      'points': points,
      'enabled': true,
      'claimedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _openEditReward(
      String id, String title, int points, bool enabled) async {
    final titleCtrl = TextEditingController(text: title);
    final ptsCtrl = TextEditingController(text: '$points');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _RewardDialog(
        title: 'Edit Reward ✨',
        titleCtrl: titleCtrl,
        pointsCtrl: ptsCtrl,
        enabled: enabled,
        confirmText: 'Save',
      ),
    );

    if (ok != true) return;

    await _rewards.doc(id).update({
      'title': titleCtrl.text.trim(),
      'points': int.tryParse(ptsCtrl.text.trim()) ?? 0,
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class _RewardsList extends StatelessWidget {
  final String parentUid;
  final String mode; // parent | child
  final String? childId;
  final int childPoints;

  final CollectionReference<Map<String, dynamic>> rewards;
  final CollectionReference<Map<String, dynamic>> claims;

  final Future<void> Function(String id, String title, int points, bool enabled)
      openEditReward;
  final Future<void> Function(String rewardId) requestClaim;

  const _RewardsList({
    required this.parentUid,
    required this.mode,
    required this.childId,
    required this.childPoints,
    required this.rewards,
    required this.claims,
    required this.openEditReward,
    required this.requestClaim,
  });

  @override
  Widget build(BuildContext context) {
    final isChild = mode == 'child';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: rewards.orderBy('createdAt', descending: false).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Text(
              isChild
                  ? 'No rewards yet ✨'
                  : 'No rewards yet — tap + to add one ✨',
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();

            final title = (data['title'] ?? 'Reward').toString();
            final ptsRaw = data['points'] ?? 0;
            final points = ptsRaw is int ? ptsRaw : int.tryParse('$ptsRaw') ?? 0;

            final enabled = (data['enabled'] ?? true) as bool;
            final claimedBy =
                List<String>.from(data['claimedBy'] ?? const <String>[]);

            final isClaimedForThisChild =
                isChild ? claimedBy.contains(childId) : false;

            if (isChild && !enabled) {
              return const SizedBox.shrink();
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE6E8FF)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          color: Color(0xFFFFC84A)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ),
                      _Pill(text: '$points pts'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!isChild)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                openEditReward(d.id, title, points, enabled),
                            child: const Text('Edit ✨'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SwitchListTile(
                            value: enabled,
                            onChanged: (v) => rewards.doc(d.id).update({
                              'enabled': v,
                              'updatedAt': FieldValue.serverTimestamp(),
                            }),
                            title: const Text('Enabled'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    if (isClaimedForThisChild)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: _Pill(text: 'Claimed ✅'),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (childPoints >= points)
                              ? () => requestClaim(d.id)
                              : null,
                          child: Text(
                            childPoints >= points
                                ? 'Request Reward ✨'
                                : 'Need ${points - childPoints} more pts',
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ChildHeader extends StatelessWidget {
  final String parentUid;
  final String childId;
  const _ChildHeader({required this.parentUid, required this.childId});

  @override
  Widget build(BuildContext context) {
    final childDoc = FirebaseFirestore.instance
        .collection('parents')
        .doc(parentUid)
        .collection('children')
        .doc(childId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: childDoc.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data = snap.data!.data() ?? {};
        final name = (data['name'] ?? 'Child').toString();
        final raw = data['points'] ?? 0;
        final pts = raw is int ? raw : int.tryParse('$raw') ?? 0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF0C8), Color(0xFFDEE7FF)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.card_giftcard_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    '$pts pts ✨',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _RewardDialog extends StatelessWidget {
  final String title;
  final TextEditingController titleCtrl;
  final TextEditingController pointsCtrl;
  final bool enabled;
  final String confirmText;

  const _RewardDialog({
    required this.title,
    required this.titleCtrl,
    required this.pointsCtrl,
    required this.enabled,
    required this.confirmText,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(labelText: 'Reward title'),
          ),
          TextField(
            controller: pointsCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Points required'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText),
        ),
      ],
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
