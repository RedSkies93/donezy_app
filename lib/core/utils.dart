import 'package:flutter/services.dart';

class AppUtils {
  /// Safe asset existence check (non-blocking). Use for optional backgrounds.
  static Future<bool> assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }
}
