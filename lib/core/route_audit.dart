import 'constants.dart';

class RouteAudit {
  /// Single list of all known routes in the app.
  /// Use this in tests / debug screens later.
  static const all = <String>[
    AppRoutes.login,
    AppRoutes.parentDashboard,
    AppRoutes.childDashboard,
    AppRoutes.messages,
    AppRoutes.awards,
    AppRoutes.settings,
  ];
}
