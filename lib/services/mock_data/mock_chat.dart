import '../../models/chat_message_model.dart';

class MockChat {
  static List<ChatMessageModel> seed() => [
        ChatMessageModel(
          id: 'm1',
          text: 'Remember: chores first, then fun ✨',
          senderId: 'parent',
          sentAt: DateTime.now(),
          seen: true,
        ),
        ChatMessageModel(
          id: 'm2',
          text: 'Okay!! 😄',
          senderId: 'child',
          sentAt: DateTime.now(),
          seen: false,
        ),
      ];
}
