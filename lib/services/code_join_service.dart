import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinResult {
  final bool success;
  final String message;
  final String? parentUid;
  final String? childId;

  const JoinResult({
    required this.success,
    required this.message,
    this.parentUid,
    this.childId,
  });
}

class CodeJoinService {
  static Future<JoinResult> joinWithCode(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const JoinResult(success: false, message: 'Not signed in.');
    }

    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) {
      return const JoinResult(success: false, message: 'Enter a code.');
    }

    final doc = FirebaseFirestore.instance.collection('codes').doc(trimmed);
    final snap = await doc.get();
    if (!snap.exists) {
      return const JoinResult(success: false, message: 'Code not found.');
    }

    final data = snap.data()!;
    final isActive = data['isActive'] == true;
    final type = (data['type'] ?? '').toString();
    final parentUid = (data['parentUid'] ?? '').toString();
    final childId = data['childId']?.toString();

    if (!isActive) {
      return const JoinResult(success: false, message: 'That code is inactive.');
    }

    if (type == 'householdShared') {
      return const JoinResult(
        success: false,
        message: 'That is a FAMILY code. Enter your KID-XXXXXX code to join your profile.',
      );
    }

    if (type != 'childPrivate' || childId == null || childId.isEmpty) {
      return const JoinResult(success: false, message: 'Invalid code type.');
    }

    // Create membership record under parent household
    final membersRef = FirebaseFirestore.instance
        .collection('parents')
        .doc(parentUid)
        .collection('members')
        .doc(user.uid);

    await membersRef.set({
      'role': 'child',
      'childId': childId,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return JoinResult(
      success: true,
      message: 'Joined!',
      parentUid: parentUid,
      childId: childId,
    );
  }
}
