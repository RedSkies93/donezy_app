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
  runApp(const MyApp());
}

/// ✅ Keeps default Flutter test templates happy (widget_test.dart often expects MyApp)
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Donezy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: false),

      home: const AppBootstrap(),

      // Routes WITHOUT arguments
      routes: {
        LoginPage.routeName: (_) => const LoginPage(),
        SettingsPage.routeName: (_) => const SettingsPage(),
        ParentDashboardPage.routeName: (_) => const ParentDashboardPage(),
      },

      // Routes WITH arguments
      onGenerateRoute: (settings) {
        // --------------------------------
        // Message Page
        // MessagePage constructor takes NO args.
        // It reads args from ModalRoute settings.arguments.
        // --------------------------------
        if (settings.name == MessagePage.routeName) {
          final args =
              (settings.arguments as Map?)?.cast<String, dynamic>() ?? {};

          final parentUid = (args['parentUid'] ?? '').toString().trim();
          final mode = (args['mode'] ?? 'parent').toString().trim();
          final childId = args['childId']; // may be null

          if (parentUid.isEmpty) {
            return _errorRoute('MessagePage requires "parentUid".', settings);
          }

          return MaterialPageRoute(
            settings: RouteSettings(
              name: settings.name,
              arguments: {
                'parentUid': parentUid,
                'mode': mode,
                'childId': childId,
              },
            ),
            builder: (_) => const MessagePage(),
          );
        }

        // --------------------------------
        // Awards Page
        // Safer to pass args via RouteSettings too.
        // If your AwardsPage constructor takes args, it can still read them.
        // --------------------------------
        if (settings.name == AwardsPage.routeName) {
          final args =
              (settings.arguments as Map?)?.cast<String, dynamic>() ?? {};

          final parentUid = (args['parentUid'] ?? '').toString().trim();
          final childId = (args['childId'] ?? '').toString().trim();

          if (parentUid.isEmpty || childId.isEmpty) {
            return _errorRoute(
              'AwardsPage requires "parentUid" and "childId".',
              settings,
            );
          }

          return MaterialPageRoute(
            settings: RouteSettings(
              name: settings.name,
              arguments: {
                'parentUid': parentUid,
                'childId': childId,
              },
            ),
            builder: (_) => const AwardsPage(),
          );
        }

        return null;
      },
    );
  }
}

/// Simple error screen for bad routes
MaterialPageRoute _errorRoute(String message, RouteSettings settings) {
  return MaterialPageRoute(
    settings: settings,
    builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Navigation Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    ),
  );
}

/// ✅ Backward compatibility if older code calls DonezyApp
class DonezyApp extends MyApp {
  const DonezyApp({super.key});
}
