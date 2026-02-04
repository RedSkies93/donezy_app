import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'screens/app_bootstrap.dart';
import 'screens/login_page.dart';
import 'screens/settings_page.dart';
import 'screens/parent_dashboard_page.dart';
import 'screens/message_page.dart';
import 'screens/awards_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const DonezyApp());
}

class DonezyApp extends StatelessWidget {
  const DonezyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Donezy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: false),
      home: const AppBootstrap(),

      // Simple named routes (no args)
      routes: {
        LoginPage.routeName: (_) => const LoginPage(),
        SettingsPage.routeName: (_) => const SettingsPage(),
        ParentDashboardPage.routeName: (_) => const ParentDashboardPage(),
      },

      // Routes that require arguments
      onGenerateRoute: (settings) {
        if (settings.name == MessagePage.routeName) {
          final args =
              (settings.arguments as Map?)?.cast<String, dynamic>() ?? {};
          final parentUid = (args['parentUid'] ?? '').toString();
          return MaterialPageRoute(
            builder: (_) => MessagePage(parentUid: parentUid),
            settings: settings,
          );
        }

        if (settings.name == AwardsPage.routeName) {
          final args =
              (settings.arguments as Map?)?.cast<String, dynamic>() ?? {};
          final parentUid = (args['parentUid'] ?? '').toString();
          final childId = (args['childId'] ?? '').toString();
          final modeStr = (args['mode'] ?? 'parent').toString();
          final mode = modeStr == 'child' ? AwardsMode.child : AwardsMode.parent;

          return MaterialPageRoute(
            builder: (_) => AwardsPage(
              parentUid: parentUid,
              childId: childId,
              mode: mode,
            ),
            settings: settings,
          );
        }

        return null;
      },
    );
  }
}
