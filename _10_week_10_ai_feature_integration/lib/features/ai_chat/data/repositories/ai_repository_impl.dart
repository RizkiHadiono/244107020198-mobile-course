import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/ai_repository.dart';
import '../datasources/ai_service.dart';

class AiRepositoryImpl implements AiRepository {
  final AiService _aiService;

  AiRepositoryImpl({AiService? aiService}) : _aiService = aiService ?? AiService();

  @override
  Future<String?> getApiKey() => _aiService.getApiKey();

  @override
  Future<void> saveApiKey(String key) => _aiService.saveApiKey(key);

  @override
  Future<void> removeApiKey() => _aiService.removeApiKey();

  @override
  Future<ChatMessage> sendMessage(String text, {List<ChatMessage> history = const []}) async {
    // Bangun riwayat untuk API: hanya pesan user/model (abaikan error & system),
    // dibatasi 10 pesan terakhir agar konsumsi token tetap efisien.
    final filtered = history.where((msg) => !msg.isError && !msg.isSystem).toList();
    final limitedHistory =
        filtered.length > 10 ? filtered.sublist(filtered.length - 10) : filtered;

    final historyMap = limitedHistory
        .map((msg) => {
              'role': msg.isUser ? 'user' : 'model',
              'text': msg.text,
            })
        .toList();

    try {
      final answer = await _aiService.ask(text, conversationHistory: historyMap);
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: answer,
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: e.toString(),
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
        isError: true,
      );
    }
  }
}
