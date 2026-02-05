import 'package:cloud_firestore/cloud_firestore.dart';

/// One-off migration helpers for chats.
///
/// Your app stores chats at:
/// parents/{parentUid}/chats/{chatId}
///
/// This migration backfills a field your rules can use:
/// - membersAuthUids: [parentUid]
///
/// (Kids may not have auth uids in your current schema. If you later add them,
/// you can extend this to include kid auth uids too.)
class ChatMigration {
  ChatMigration._();

  static CollectionReference<Map<String, dynamic>> _chatsCol(String parentUid) {
    return FirebaseFirestore.instance
        .collection('parents')
        .doc(parentUid)
        .collection('chats');
  }

  /// Safe to run repeatedly.
  ///
  /// Adds/merges:
  /// - membersAuthUids: [parentUid]
  /// - updatedAt: server timestamp
  ///
  /// Returns number of chat docs updated.
  static Future<int> backfillMembersAuthUids({required String parentUid}) async {
    final snap = await _chatsCol(parentUid).get();
    if (snap.docs.isEmpty) return 0;

    final batch = FirebaseFirestore.instance.batch();
    int updated = 0;

    for (final d in snap.docs) {
      final data = d.data();

      // If field exists and already contains parentUid, skip.
      final existing = (data['membersAuthUids'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          <String>{};

      if (existing.contains(parentUid)) continue;

      final next = {...existing, parentUid}.toList();

      batch.set(
        d.reference,
        {
          'membersAuthUids': next,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      updated++;
    }

    if (updated > 0) {
      await batch.commit();
    }
    return updated;
  }

  /// Optional: keep a lightweight initializer if you want to ensure structure.
  static Future<void> ensureParentChatInitialized(String parentUid) async {
    final parentDoc =
        FirebaseFirestore.instance.collection('parents').doc(parentUid);

    await parentDoc.set(
      {'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}
