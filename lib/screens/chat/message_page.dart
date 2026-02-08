import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/app_shell.dart';
import '../../widgets/pastel_card.dart';
import '../../widgets/screen_background.dart';
import '../../widgets/bubble_button.dart';

import '../../core/asset_registry.dart';
import '../../core/constants.dart';

import '../../services/chat_service.dart';
import '../../services/chat_store.dart';
import '../../actions/chat/send_message_action.dart';

import '../../actions/navigation/go_to_dashboard_action.dart';
import '../../actions/navigation/go_to_messages_action.dart';
import '../../actions/navigation/go_to_awards_action.dart';
import '../../actions/navigation/go_to_settings_action.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  bool _loaded = false;
  final _controller = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;

    context.read<ChatService>().load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.read<ChatService>();
    final store = context.watch<ChatStore>();
    final send = SendMessageAction();

    final goDash = GoToDashboardAction();
    final goMsg = GoToMessagesAction();
    final goAwards = GoToAwardsAction();
    final goSettings = GoToSettingsAction();

    return AppShell(
      title: 'Messages',
      currentIndex: 1,
      onNavTap: (i) {
        switch (i) {
          case 0:
            goDash.run(context);
            break;
          case 1:
            goMsg.run(context);
            break;
          case 2:
            goAwards.run(context);
            break;
          case 3:
            goSettings.run(context);
            break;
        }
      },
      body: ScreenBackground(
        assetPath: AssetRegistry.bgChat,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                reverse: true,
                children: [
                  PastelCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Family Chat 💬',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                            'Phase 3: Live chat store + send action (mock).'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.cardGap),
                  if (store.messages.isEmpty)
                    const PastelCard(child: Text('No messages yet...'))
                  else
                    ...store.messages.map((m) {
                      final isParent = m.senderId == 'parent';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Align(
                          alignment: isParent
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: PastelCard(
                              child: Text(m.text),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page, 0, AppSpacing.page, AppSpacing.page),
              child: PastelCard(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _send(chat, send),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 90,
                      child: BubbleButton(
                        onPressed: () => _send(chat, send),
                        child: const Text('Send'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _send(ChatService chat, SendMessageAction send) {
    final text = _controller.text;
    send.run(service: chat, senderId: 'parent', text: text);
    _controller.clear();
  }
}
