import '../entities/chat_message.dart';
import '../repositories/ai_repository.dart';

class SendMessageUseCase {
  final AiRepository _repository;

  SendMessageUseCase(this._repository);

  Future<ChatMessage> call(String text, {List<ChatMessage> history = const []}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Pesan tidak boleh kosong.');
    }
    return await _repository.sendMessage(trimmed, history: history);
  }
}
