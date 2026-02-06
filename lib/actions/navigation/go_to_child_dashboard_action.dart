import 'package:flutter/material.dart';
import '../../core/action_result.dart';
import '../../core/constants.dart';

class GoToChildDashboardAction {
  Future<ActionResult<void>> run(BuildContext context) async {
    Navigator.pushNamed(context, AppRoutes.childDashboard);
    return const ActionResult.success();
  }
}
