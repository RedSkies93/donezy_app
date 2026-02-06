import 'package:flutter/material.dart';
import '../../core/action_result.dart';
import '../../core/constants.dart';

class GoToSettingsAction {
  Future<ActionResult<void>> run(BuildContext context) async {
    Navigator.pushNamed(context, AppRoutes.settings);
    return const ActionResult.success();
  }
}
