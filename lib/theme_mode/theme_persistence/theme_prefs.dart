import 'package:flutter/material.dart';

class ThemePrefs {
  // Phase 1: placeholder (in-memory only)
  Future<ThemeMode?> read() async => null;

  // Phase 3: implement persistence (SharedPreferences)
  Future<void> write(ThemeMode mode) async {}
}
