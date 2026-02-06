import '../../core/action_result.dart';
import '../../services/chat_service.dart';

class SendMessageAction {
  Future<ActionResult<void>> run({
    required ChatService service,
    required String senderId,
    required String text,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return const ActionResult.failure('Message is empty.');

    await service.send(senderId: senderId, text: clean);
    return const ActionResult.success();
  }
}
