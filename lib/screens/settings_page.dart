import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/chat_migration.dart';


class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  static const routeName = '/settings';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = FirebaseFirestore.instance.collection('parents').doc(uid).collection('meta').doc('profile');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(title: const Text('Settings ⚙️'), centerTitle: true),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: doc.snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() ?? {};
          final darkMode = (data['darkMode'] ?? false) as bool;
          final importantDefault = (data['importantByDefault'] ?? false) as bool;

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(14),
            children: [
              _Card(
                child: SwitchListTile(
                  value: darkMode,
                  onChanged: (v) => doc.set({'darkMode': v, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)),
                  title: const Text('Dark Mode 🌙', style: TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: const Text('Saved per profile'),
                ),
              ),
              const SizedBox(height: 10),
              _Card(
                child: SwitchListTile(
                  value: importantDefault,
                  onChanged: (v) => doc.set({'importantByDefault': v, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)),
                  title: const Text('New tasks are Important by default ✨', style: TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: const Text('Parent task creation preference'),
                ),
              ),
              const SizedBox(height: 10),
              const _Card(
                child: ListTile(
                  title: Text('Coming Soon', style: TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('Notifications • Point rules • Child permissions • Personalization'),
                ),
              ),
              const SizedBox(height: 10),
_Card(
  child: ListTile(
    title: const Text('Fix Chats (Run Once) 🛠️',
        style: TextStyle(fontWeight: FontWeight.w900)),
    subtitle: const Text('Backfills membersAuthUids so chat rules work.'),
    trailing: const Icon(Icons.play_circle_fill_rounded),
    onTap: () async {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // quick confirmation
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Run chat migration?'),
          content: const Text(
              'This updates your existing chat docs once. Safe to run again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Run'),
            ),
          ],
        ),
      );

      if (ok != true) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Running migration…')),
      );

      try {
        final count = await ChatMigration.backfillMembersAuthUids(parentUid: uid);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Done! Updated $count chats ✅')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Migration failed: $e')),
        );
      }
    },
  ),
),

            ],
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E8FF)),
      ),
      child: child,
    );
  }
}
