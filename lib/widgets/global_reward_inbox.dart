import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GlobalRewardInbox extends StatelessWidget {
  final String parentUid;
  const GlobalRewardInbox({super.key, required this.parentUid});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    final childrenRef = db.collection('parents').doc(parentUid).collection('children');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: childrenRef.snapshots(),
      builder: (context, kidsSnap) {
        final kids = kidsSnap.data?.docs ?? [];
        if (kids.isEmpty) return const SizedBox.shrink();

        return FutureBuilder<List<_PendingClaim>>(
          future: _loadPending(parentUid, kids.map((k) => k.id).toList()),
          builder: (context, pendingSnap) {
            final pending = pendingSnap.data ?? [];
            if (pending.isEmpty) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE6E8FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reward Requests 🎁',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ...pending.map((p) => _PendingClaimTile(parentUid: parentUid, claim: p)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<_PendingClaim>> _loadPending(String parentUid, List<String> childIds) async {
    final db = FirebaseFirestore.instance;
    final results = <_PendingClaim>[];

    for (final childId in childIds) {
      final claimsRef = db
          .collection('parents')
          .doc(parentUid)
          .collection('children')
          .doc(childId)
          .collection('rewardClaims');

      final snap = await claimsRef
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      for (final d in snap.docs) {
        results.add(_PendingClaim(
          childId: childId,
          claimId: d.id,
          rewardId: (d.data()['rewardId'] ?? '').toString(),
        ));
      }
    }

    return results;
  }
}

class _PendingClaim {
  final String childId;
  final String claimId;
  final String rewardId;

  _PendingClaim({
    required this.childId,
    required this.claimId,
    required this.rewardId,
  });
}

class _PendingClaimTile extends StatelessWidget {
  final String parentUid;
  final _PendingClaim claim;

  const _PendingClaimTile({required this.parentUid, required this.claim});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    final rewardDoc =
        db.collection('parents').doc(parentUid).collection('rewards').doc(claim.rewardId);
    final childDoc =
        db.collection('parents').doc(parentUid).collection('children').doc(claim.childId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6E8FF)),
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: Future.wait([
            childDoc.get().then((d) => d.data() ?? {}),
            rewardDoc.get().then((d) => d.data() ?? {}),
          ]),
          builder: (context, snap) {
            final child = (snap.data != null && snap.data!.isNotEmpty) ? snap.data![0] : {};
            final reward = (snap.data != null && snap.data!.length > 1) ? snap.data![1] : {};

            final childName = (child['name'] ?? 'Child').toString();
            final rewardTitle = (reward['title'] ?? 'Reward').toString();

            return Row(
              children: [
                Expanded(
                  child: Text(
                    '$childName requested: $rewardTitle',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Reject',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () async {
                    await db
                        .collection('parents')
                        .doc(parentUid)
                        .collection('children')
                        .doc(claim.childId)
                        .collection('rewardClaims')
                        .doc(claim.claimId)
                        .update({
                      'status': 'rejected',
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rejected 🫧')),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Approve',
                  icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF17C9B2)),
                  onPressed: () async {
                    await db
                        .collection('parents')
                        .doc(parentUid)
                        .collection('children')
                        .doc(claim.childId)
                        .collection('rewardClaims')
                        .doc(claim.claimId)
                        .update({
                      'status': 'approved',
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    await db.collection('parents').doc(parentUid).collection('rewards').doc(claim.rewardId).set({
                      'claimedBy': FieldValue.arrayUnion([claim.childId]),
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Approved 🎉')),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
