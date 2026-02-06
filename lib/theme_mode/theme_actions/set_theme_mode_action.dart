import 'package:flutter/material.dart';
import '../../core/action_result.dart';
import '../theme_store.dart';

class SetThemeModeAction {
  Future<ActionResult<void>> run({
    required ThemeStore store,
    required ThemeMode mode,
  }) async {
    store.setMode(mode);
    return const ActionResult.success();
  }
}
