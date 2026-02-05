import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/session_store.dart';
import 'login_page.dart';
import 'role_select_page.dart';
import 'parent_dashboard_page.dart';
import 'child_dashboard_page.dart';

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }

        final user = snap.data;
        if (user == null) return const LoginPage();

        return FutureBuilder<SessionData>(
          future: SessionStore.load(),
          builder: (context, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const _Splash();
            }

            final session = s.data ?? const SessionData();

            if (session.role == null) return const RoleSelectPage();

            if (session.role == SessionRole.parent) {
              return const ParentDashboardPage();
            }

            if (session.role == SessionRole.child &&
                session.parentUid != null &&
                session.childId != null) {
              return ChildDashboardPage(
                parentUid: session.parentUid!,
                childId: session.childId!,
              );
            }

            return const RoleSelectPage();
          },
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8F9FF),
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}
