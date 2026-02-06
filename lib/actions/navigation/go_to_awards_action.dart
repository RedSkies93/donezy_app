import 'package:flutter/material.dart';
import '../../core/action_result.dart';
import '../../core/constants.dart';

class GoToAwardsAction {
  Future<ActionResult<void>> run(BuildContext context) async {
    Navigator.pushNamed(context, AppRoutes.awards);
    return const ActionResult.success();
  }
}
