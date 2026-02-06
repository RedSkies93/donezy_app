import '../models/chat_message_model.dart';
import 'chat_store.dart';
import 'mock_data/mock_chat.dart';

class ChatService {
  final ChatStore store;

  ChatService(this.store);

  Future<void> load() async {
    store.setMessages(MockChat.seed());
  }

  Future<void> send({
    required String senderId,
    required String text,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    store.addMessage(
      ChatMessageModel(
        id: 'm_${DateTime.now().microsecondsSinceEpoch}',
        text: clean,
        senderId: senderId,
        sentAt: DateTime.now(),
        seen: false,
      ),
    );
  }
}
