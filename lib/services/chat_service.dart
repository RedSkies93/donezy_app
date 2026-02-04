import 'package:cloud_firestore/cloud_firestore.dart';

/// Minimal Firestore-backed chat service.
///
/// Data model (defaults):
/// - `chats/{chatId}`: { parentUid, childUid, createdAt, updatedAt }
/// - `chats/{chatId}/messages/{messageId}`: { text, senderUid, createdAt }
class ChatService {
  final FirebaseFirestore _firestore;

  ChatService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Creates (if needed) and returns a stable chat id for a parent/child pair.
  ///
  /// This matches the common UI usage:
  /// `final chatId = await ChatService().createOrGetChat(parentUid: ..., childUid: ...);`
  Future<String> createOrGetChat({
    required String parentUid,
    required String childUid,
  }) async {
    final chatId = _stableChatId(parentUid: parentUid, childUid: childUid);
    final ref = _firestore.collection('chats').doc(chatId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        tx.update(ref, {'updatedAt': FieldValue.serverTimestamp()});
        return;
      }

      tx.set(ref, {
        'parentUid': parentUid,
        'childUid': childUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return chatId;
  }

  DocumentReference<Map<String, dynamic>> chatRef(String chatId) =>
      _firestore.collection('chats').doc(chatId);

  CollectionReference<Map<String, dynamic>> messagesRef(String chatId) =>
      chatRef(chatId).collection('messages');

  static String _stableChatId({
    required String parentUid,
    required String childUid,
  }) {
    // Keep doc ids short and deterministic. Using a fixed order (parent, child)
    // avoids accidentally creating two chats for the same pair.
    return '${parentUid}_$childUid';
  }
}
