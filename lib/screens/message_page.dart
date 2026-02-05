import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/chat_service.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});
  static const routeName = '/messages';

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  late final String parentUid;
  late final String mode; // 'parent' | 'child'
  String? childId;

  String get myId => mode == 'parent' ? 'parent' : (childId ?? 'child');

  CollectionReference<Map<String, dynamic>> get _chats =>
      FirebaseFirestore.instance.collection('parents').doc(parentUid).collection('chats');

  CollectionReference<Map<String, dynamic>> get _children =>
      FirebaseFirestore.instance.collection('parents').doc(parentUid).collection('children');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    parentUid = args['parentUid'];
    mode = (args['mode'] ?? 'parent').toString();
    childId = args['childId']?.toString();
  }

  bool _visibleToMe(Map<String, dynamic> chat) {
    if (mode == 'parent') return true;
    final members = List<String>.from(chat['membersChildIds'] ?? const <String>[]);
    return members.contains(childId);
  }

  Future<void> _openCreateChatSheet() async {
    final childrenSnap = await _children.orderBy('createdAt', descending: false).get();
    final kids = childrenSnap.docs;
    if (kids.isEmpty || !mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      builder: (_) => _CreateChatSheet(
        kids: kids,
        onCreateFamily: () async {
          final allIds = kids.map((e) => e.id).toList();

          // ✅ FIX: static call
          final ref = await ChatService.createOrGetChat(
            parentUid: parentUid,
            type: 'family',
            memberChildIds: allIds,
            title: 'Family Chat 💖',
          );

          if (!mounted) return;
          Navigator.pop(context);
          _openThread(chatId: ref.id, title: 'Family Chat 💖');
        },
        onCreateParentChild: (kidId, kidName) async {
          // ✅ FIX: static call
          final ref = await ChatService.createOrGetChat(
            parentUid: parentUid,
            type: 'parent_child',
            memberChildIds: [kidId],
            title: 'Parent + $kidName ✨',
          );

          if (!mounted) return;
          Navigator.pop(context);
          _openThread(chatId: ref.id, title: 'Parent + $kidName ✨');
        },
        onCreateKids: (kidAId, kidAName, kidBId, kidBName) async {
          // ✅ FIX: static call
          final ref = await ChatService.createOrGetChat(
            parentUid: parentUid,
            type: 'kids',
            memberChildIds: [kidAId, kidBId],
            title: '$kidAName + $kidBName 🧸',
          );

          if (!mounted) return;
          Navigator.pop(context);
          _openThread(chatId: ref.id, title: '$kidAName + $kidBName 🧸');
        },
      ),
    );
  }

  void _openThread({required String chatId, required String title}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChatThreadPage(
          parentUid: parentUid,
          chatId: chatId,
          title: title,
          mode: mode,
          childId: childId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: const Text('Messages 💬'),
        centerTitle: true,
        actions: [
          if (mode == 'parent')
            IconButton(
              tooltip: 'New Chat',
              onPressed: _openCreateChatSheet,
              icon: const Icon(Icons.add_circle_rounded),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _chats.orderBy('updatedAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs.where((d) => _visibleToMe(d.data())).toList();
          if (docs.isEmpty) {
            return _EmptyState(
              title: 'No messages yet ✨',
              subtitle: mode == 'parent'
                  ? 'Tap + to create your first chat!'
                  : 'Your parent will start a chat soon.',
            );
          }

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = docs[i];
              final chat = d.data();

              final title = (chat['title'] ?? 'Chat').toString();
              final lastMessage = (chat['lastMessage'] ?? '').toString();

              final unreadCounts = (chat['unreadCounts'] ?? {}) as Map<String, dynamic>;
              final unreadRaw = unreadCounts[myId] ?? 0;
              final unread = unreadRaw is int ? unreadRaw : int.tryParse('$unreadRaw') ?? 0;

              final lastSenderId = (chat['lastSenderId'] ?? '').toString();
              final lastSeenBy = List<String>.from(chat['lastSeenBy'] ?? const <String>[]);

              final iSentLast = lastSenderId == myId;
              final someoneSaw = iSentLast && lastSeenBy.any((x) => x != myId);

              return _ChatTile(
                title: title,
                subtitle: lastMessage,
                unread: unread,
                showSeenEyes: someoneSaw,
                onTap: () => _openThread(chatId: d.id, title: title),
              );
            },
          );
        },
      ),
    );
  }
}

class _CreateChatSheet extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> kids;
  final VoidCallback onCreateFamily;
  final Future<void> Function(String kidId, String kidName) onCreateParentChild;
  final Future<void> Function(
    String kidAId,
    String kidAName,
    String kidBId,
    String kidBName,
  ) onCreateKids;

  const _CreateChatSheet({
    required this.kids,
    required this.onCreateFamily,
    required this.onCreateParentChild,
    required this.onCreateKids,
  });

  @override
  State<_CreateChatSheet> createState() => _CreateChatSheetState();
}

class _CreateChatSheetState extends State<_CreateChatSheet> {
  String? _kidA;
  String? _kidB;

  @override
  Widget build(BuildContext context) {
    final kids = widget.kids;

    String nameOf(String id) {
      final d = kids.firstWhere((e) => e.id == id);
      return (d.data()['name'] ?? 'Child').toString();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Create a chat ✨',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: widget.onCreateFamily,
                child: const Text('Family Chat 💖'),
              ),
            ),

            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Parent ↔ Child', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: kids.map((d) {
                final name = (d.data()['name'] ?? 'Child').toString();
                return OutlinedButton(
                  onPressed: () => widget.onCreateParentChild(d.id, name),
                  child: Text(name),
                );
              }).toList(),
            ),

            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Kid ↔ Kid (parent can view)',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _kidA,
                    items: kids
                        .map((d) => DropdownMenuItem(
                              value: d.id,
                              child: Text((d.data()['name'] ?? 'Child').toString()),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _kidA = v),
                    decoration: const InputDecoration(labelText: 'Kid A'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _kidB,
                    items: kids
                        .map((d) => DropdownMenuItem(
                              value: d.id,
                              child: Text((d.data()['name'] ?? 'Child').toString()),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _kidB = v),
                    decoration: const InputDecoration(labelText: 'Kid B'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (_kidA == null || _kidB == null || _kidA == _kidB)
                    ? null
                    : () => widget.onCreateKids(
                          _kidA!,
                          nameOf(_kidA!),
                          _kidB!,
                          nameOf(_kidB!),
                        ),
                child: const Text('Create Kid Chat 🧸'),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final int unread;
  final bool showSeenEyes;
  final VoidCallback onTap;

  const _ChatTile({
    required this.title,
    required this.subtitle,
    required this.unread,
    required this.showSeenEyes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: Color(0xFFB9D7FF),
              child: Icon(Icons.chat_bubble_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black.withOpacity(0.60)),
                  ),
                ],
              ),
            ),
            if (unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFFF7AA2), borderRadius: BorderRadius.circular(18)),
                child: Text('$unread', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              )
            else if (showSeenEyes)
              const Text('👀'),
          ],
        ),
      ),
    );
  }
}

class _ChatThreadPage extends StatefulWidget {
  final String parentUid;
  final String chatId;
  final String title;
  final String mode;
  final String? childId;

  const _ChatThreadPage({
    required this.parentUid,
    required this.chatId,
    required this.title,
    required this.mode,
    required this.childId,
  });

  @override
  State<_ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<_ChatThreadPage> {
  final _ctrl = TextEditingController();

  String get myId {
    if (widget.mode == 'parent') return 'parent';
    return FirebaseAuth.instance.currentUser!.uid;
  }

  DocumentReference<Map<String, dynamic>> get _chatDoc =>
      FirebaseFirestore.instance.collection('parents').doc(widget.parentUid).collection('chats').doc(widget.chatId);

  CollectionReference<Map<String, dynamic>> get _msgs => _chatDoc.collection('messages');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  Future<void> _markRead() async {
    await _chatDoc.set({
      'unreadCounts': {myId: 0},
      'lastSeenBy': FieldValue.arrayUnion([myId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final q = await _msgs.orderBy('createdAt', descending: true).limit(50).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in q.docs) {
      final data = d.data();
      final seenBy = List<String>.from(data['seenBy'] ?? const <String>[]);
      if (!seenBy.contains(myId)) {
        batch.update(d.reference, {'seenBy': FieldValue.arrayUnion([myId])});
      }
    }
    await batch.commit();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final chatSnap = await tx.get(_chatDoc);
      final chat = chatSnap.data() ?? {};

      final membersChildIds = List<String>.from(chat['membersChildIds'] ?? const <String>[]);
      final participants = <String>{'parent', ...membersChildIds};

      final msgRef = _msgs.doc();
      tx.set(msgRef, {
        'text': text,
        'senderId': myId,
        'createdAt': FieldValue.serverTimestamp(),
        'seenBy': [myId],
      });

      final unreadCounts = Map<String, dynamic>.from(chat['unreadCounts'] ?? {});
      for (final p in participants) {
        if (p == myId) continue;
        final cur = unreadCounts[p] ?? 0;
        final curInt = cur is int ? cur : int.tryParse('$cur') ?? 0;
        unreadCounts[p] = curInt + 1;
      }
      unreadCounts[myId] = 0;

      tx.set(_chatDoc, {
        'lastMessage': text,
        'lastSenderId': myId,
        'lastSeenBy': [myId],
        'unreadCounts': unreadCounts,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _msgs.orderBy('createdAt').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data();
                    final text = (data['text'] ?? '').toString();
                    final senderId = (data['senderId'] ?? '').toString();
                    final seenBy = List<String>.from(data['seenBy'] ?? const <String>[]);

                    final isMe = senderId == myId;
                    final seenByOther = isMe && seenBy.any((x) => x != myId);

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFFBFF6E9) : const Color(0xFFDEE7FF),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          if (seenByOther)
                            const Padding(
                              padding: EdgeInsets.only(right: 6, bottom: 2),
                              child: Text('👀', style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.send_rounded), onPressed: _send),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_rounded, size: 48, color: Color(0xFFB9D7FF)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
