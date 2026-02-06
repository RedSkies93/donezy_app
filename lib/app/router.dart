import 'package:flutter/material.dart';
import '../core/constants.dart';

// Screens
import '../screens/login/login_page.dart';
import '../screens/parent/parent_dashboard_page.dart';
import '../screens/child/child_dashboard_page.dart';
import '../screens/chat/message_page.dart';
import '../screens/awards/awards_page.dart';
import '../screens/settings/settings_page.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case AppRoutes.parentDashboard:
        return MaterialPageRoute(builder: (_) => const ParentDashboardPage());
      case AppRoutes.childDashboard:
        return MaterialPageRoute(builder: (_) => const ChildDashboardPage());
      case AppRoutes.messages:
        return MaterialPageRoute(builder: (_) => const MessagePage());
      case AppRoutes.awards:
        return MaterialPageRoute(builder: (_) => const AwardsPage());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsPage());
      default:
        return MaterialPageRoute(builder: (_) => const LoginPage());
    }
  }
}
