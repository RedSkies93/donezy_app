import 'package:flutter/material.dart';
import '../../core/action_result.dart';
import '../../core/constants.dart';

class GoToDashboardAction {
  Future<ActionResult<void>> run(BuildContext context) async {
    Navigator.pushNamed(context, AppRoutes.parentDashboard);
    return const ActionResult.success();
  }
}
