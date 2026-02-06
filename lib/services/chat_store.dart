import 'package:flutter/foundation.dart';
import '../models/chat_message_model.dart';

class ChatStore extends ChangeNotifier {
  List<ChatMessageModel> _messages = const [];

  List<ChatMessageModel> get messages => _messages;

  void setMessages(List<ChatMessageModel> items) {
    _messages = List.unmodifiable(items);
    notifyListeners();
  }

  void addMessage(ChatMessageModel msg) {
    _messages = List.unmodifiable([msg, ..._messages]);
    notifyListeners();
  }
}
