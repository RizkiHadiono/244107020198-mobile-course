import '../entities/chat_message.dart';

abstract class AiRepository {
  Future<String?> getApiKey();
  Future<void> saveApiKey(String key);
  Future<void> removeApiKey();
  Future<ChatMessage> sendMessage(String text, {List<ChatMessage> history = const []});
}
