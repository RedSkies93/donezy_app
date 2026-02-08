import 'package:flutter/material.dart';

class ThemePrefs {
  // Phase 1: in-memory only.
// Later phase: persist using shared_preferences (or secure storage if needed).
  Future<ThemeMode?> read() async => null;

  // Phase 3: implement persistence (SharedPreferences)
  Future<void> write(ThemeMode mode) async {}
}
