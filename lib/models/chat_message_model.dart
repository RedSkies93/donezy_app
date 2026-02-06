class ChatMessageModel {
  final String id;
  final String text;
  final String senderId;
  final DateTime sentAt;
  final bool seen;

  const ChatMessageModel({
    required this.id,
    required this.text,
    required this.senderId,
    required this.sentAt,
    this.seen = false,
  });
}
