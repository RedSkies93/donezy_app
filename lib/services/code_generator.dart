import 'dart:math';

class CodeGenerator {
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String kidCode({int length = 6}) {
    final r = Random.secure();
    final buf = StringBuffer('KID-');
    for (var i = 0; i < length; i++) {
      buf.write(_chars[r.nextInt(_chars.length)]);
    }
    return buf.toString();
  }
}
