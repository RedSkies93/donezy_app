import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/session_store.dart';
import '../services/code_generator.dart';
import 'child_join_page.dart';
import 'parent_dashboard_page.dart';

class RoleSelectPage extends StatefulWidget {
  const RoleSelectPage({super.key});
  static const routeName = '/role';

  @override
  State<RoleSelectPage> createState() => _RoleSelectPageState();
}

class _RoleSelectPageState extends State<RoleSelectPage> {
  bool _busy = false;
  String? _error;

  Future<void> _chooseParent() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in.');

      // Make sure parent doc exists (create shared code if missing)
      final parents = FirebaseFirestore.instance.collection('parents');
      final ref = parents.doc(user.uid);
      final snap = await ref.get();

      if (!snap.exists) {
        final sharedCode = await CodeGenerator.generateUniqueHouseholdCode(parentUid: user.uid);
        await ref.set({
          'displayName': user.email ?? 'Parent',
          'photoUrl': null,
          'sharedCode': sharedCode,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // mark member role
      await ref.collection('members').doc(user.uid).set({
        'role': 'parent',
        'childId': null,
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await SessionStore.setRole(SessionRole.parent);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ParentDashboardPage()),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseChild() async {
    setState(() => _error = null);
    await SessionStore.setRole(SessionRole.child);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ChildJoinPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                'Who are you?',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text('Pick one — you can change later in Settings.'),
              const SizedBox(height: 18),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),

              _RoleButton(
                title: 'I am a Parent',
                subtitle: 'Create kids • Make tasks • Track progress',
                icon: Icons.shield_moon_rounded,
                onTap: _busy ? null : _chooseParent,
              ),
              const SizedBox(height: 12),
              _RoleButton(
                title: 'I am a Child',
                subtitle: 'Join with a code • Do tasks • Earn points',
                icon: Icons.emoji_events_rounded,
                onTap: _busy ? null : _chooseChild,
              ),

              const Spacer(),
              if (_busy) const CircularProgressIndicator(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _RoleButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE6E8FF)),
          boxShadow: const [
            BoxShadow(blurRadius: 16, color: Color(0x14000000), offset: Offset(0, 10))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF2FF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

