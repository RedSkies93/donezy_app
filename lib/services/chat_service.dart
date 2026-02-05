import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  static final _db = FirebaseFirestore.instance;

  /// Creates or returns a chat doc for a parent + a set of children.
  /// This matches your MessagePage calls: type, memberChildIds, title.
  static Future<DocumentReference<Map<String, dynamic>>> createOrGetChat({
    required String parentUid,
    required String type, // 'family' | 'parent_child' | 'kids'
    required List<String> memberChildIds,
    required String title,
  }) async {
    final chats = _db.collection('parents').doc(parentUid).collection('chats');

    // Deterministic key to avoid duplicates:
    final sortedKids = [...memberChildIds]..sort();
    final key = '$type:${sortedKids.join(",")}';
    final chatId = key.replaceAll(RegExp(r'[^a-zA-Z0-9:_,-]'), '_');

    final ref = chats.doc(chatId);
    final snap = await ref.get();
    if (snap.exists) return ref;

    await ref.set({
      'type': type,
      'title': title,
      'membersChildIds': sortedKids,
      // For rules/migration compatibility:
      'membersAuthUids': <String>[parentUid, ...sortedKids],
      'lastMessage': '',
      'lastSenderId': '',
      'lastSeenBy': <String>[],
      'unreadCounts': <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref;
  }
}
