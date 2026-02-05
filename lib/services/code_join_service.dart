import 'package:cloud_firestore/cloud_firestore.dart';

class JoinResult {
  final bool success;
  final String message;
  final String? parentUid;
  final String? childId;
  final String? joinCode;

  const JoinResult({
    required this.success,
    required this.message,
    this.parentUid,
    this.childId,
    this.joinCode,
  });

  static JoinResult ok({required String parentUid, required String childId, required String joinCode}) {
    return JoinResult(success: true, message: 'OK', parentUid: parentUid, childId: childId, joinCode: joinCode);
  }

  static JoinResult fail(String message) {
    return JoinResult(success: false, message: message);
  }
}

class CodeJoinService {
  static Future<JoinResult> joinWithCode(String raw) async {
    final code = raw.trim().toUpperCase();
    if (code.isEmpty) return JoinResult.fail('Enter a code.');

    final snap = await FirebaseFirestore.instance
        .collectionGroup('children')
        .where('joinCode', isEqualTo: code)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      return JoinResult.fail('Code not found.');
    }

    final doc = snap.docs.first;
    final childId = doc.id;

    // Path: parents/{parentUid}/children/{childId}
    final parentUid = doc.reference.parent.parent?.id;
    if (parentUid == null) {
      return JoinResult.fail('Invalid code reference.');
    }

    return JoinResult.ok(parentUid: parentUid, childId: childId, joinCode: code);
  }
}
