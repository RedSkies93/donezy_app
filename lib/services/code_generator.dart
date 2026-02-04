import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class CodeGenerator {
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I
  static final _rand = Random.secure();

  static String _chunk(int len) {
    final b = StringBuffer();
    for (int i = 0; i < len; i++) {
      b.write(_alphabet[_rand.nextInt(_alphabet.length)]);
    }
    return b.toString();
  }

  static Future<String> generateUniqueHouseholdCode({required String parentUid}) async {
    return _generateUnique(
      prefix: 'FAM',
      parentUid: parentUid,
      childId: null,
      type: 'householdShared',
    );
  }

  static Future<String> generateUniqueChildCode({
    required String parentUid,
    required String childId,
  }) async {
    return _generateUnique(
      prefix: 'KID',
      parentUid: parentUid,
      childId: childId,
      type: 'childPrivate',
    );
  }

  static Future<String> _generateUnique({
    required String prefix,
    required String parentUid,
    required String? childId,
    required String type,
  }) async {
    final codes = FirebaseFirestore.instance.collection('codes');

    for (int attempt = 0; attempt < 25; attempt++) {
      final code = '$prefix-${_chunk(6)}';
      final doc = codes.doc(code);

      try {
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final snap = await tx.get(doc);
          if (snap.exists) {
            throw StateError('collision');
          }
          tx.set(doc, {
            'parentUid': parentUid,
            'childId': childId,
            'type': type,
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });
        return code;
      } catch (e) {
        // collision or transient issue; try again
      }
    }

    throw Exception('Failed to generate a unique code. Try again.');
  }
}
