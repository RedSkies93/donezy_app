import 'package:flutter/material.dart';

import '../services/session_store.dart';
import 'parent_dashboard_page.dart';
import 'child_join_page.dart';

class RoleSelectPage extends StatelessWidget {
  const RoleSelectPage({super.key});
  static const routeName = '/role';

  Future<void> _setParent(BuildContext context) async {
    await SessionStore.setRole(SessionRole.parent);
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ParentDashboardPage()),
      (_) => false,
    );
  }

  Future<void> _setChild(BuildContext context) async {
    await SessionStore.setRole(SessionRole.child);
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChildJoinPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: const Text('Who are you? ✨'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const SizedBox(height: 6),
            const Text(
              'Pick your role',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),

            _RoleCard(
              title: 'Parent / Guardian',
              subtitle: 'Create kids, add tasks, approve rewards, view chats',
              emoji: '👨‍👩‍👧‍👦',
              onTap: () => _setParent(context),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              title: 'Child',
              subtitle: 'Join your household with a code and start completing tasks',
              emoji: '🧸',
              onTap: () => _setChild(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE6E8FF)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black.withOpacity(0.65))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

