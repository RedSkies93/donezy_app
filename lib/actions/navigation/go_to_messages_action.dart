import 'package:flutter/material.dart';
import '../../core/action_result.dart';
import '../../core/constants.dart';

class GoToMessagesAction {
  Future<ActionResult<void>> run(BuildContext context) async {
    Navigator.pushNamed(context, AppRoutes.messages);
    return const ActionResult.success();
  }
}
