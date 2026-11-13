import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/ai_service.dart';
import '../../data/repositories/ai_repository_impl.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/ai_repository.dart';
import '../../domain/usecases/send_message.dart';

// Service & Repository Providers
final aiServiceProvider = Provider<AiService>((ref) => AiService());

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  final service = ref.watch(aiServiceProvider);
  return AiRepositoryImpl(aiService: service);
});

final sendMessageUseCaseProvider = Provider<SendMessageUseCase>((ref) {
  final repo = ref.watch(aiRepositoryProvider);
  return SendMessageUseCase(repo);
});

// Provider status tersedianya API Key
final hasApiKeyProvider = FutureProvider.autoDispose<bool>((ref) async {
  final repo = ref.watch(aiRepositoryProvider);
  final key = await repo.getApiKey();
  return key != null && key.trim().isNotEmpty;
});

// State untuk daftar pesan Chat
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    return ChatState(
      messages: [
        ChatMessage(
          id: 'init_welcome',
          text: 'Halo! Saya asisten pintar POLINEMA. Ada yang bisa saya bantu seputar perkuliahan, jadwal, atau tugas?',
          sender: MessageSender.ai,
          timestamp: DateTime.now(),
        )
      ],
    );
  }

  Future<void> sendUserMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || state.isLoading) return;

    final repo = ref.read(aiRepositoryProvider);
    final sendMessageUseCase = ref.read(sendMessageUseCaseProvider);

    // Periksa API Key terlebih dahulu
    final apiKey = await repo.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      final keyWarning = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: 'API Key belum diset! Silakan buka Pengaturan API Key di pojok kanan atas untuk memasukkan Gemini API Key.',
        sender: MessageSender.system,
        timestamp: DateTime.now(),
        isError: true,
      );
      state = state.copyWith(
        messages: [...state.messages, keyWarning],
      );
      return;
    }

    // Tambah pesan user ke list
    final userMessage = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: cleanText,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    final updatedMessages = [...state.messages, userMessage];
    state = state.copyWith(
      messages: updatedMessages,
      isLoading: true,
      errorMessage: null,
    );

    try {
      final response = await sendMessageUseCase(cleanText, history: updatedMessages);
      state = state.copyWith(
        messages: [...state.messages, response],
        isLoading: false,
      );
    } catch (e) {
      final errorMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: 'Terjadi kesalahan: $e',
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
        isError: true,
      );
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void clearChat() {
    state = ChatState(
      messages: [
        ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          text: 'Obrolan telah dibersihkan. Ada pertanyaan baru yang ingin diajukan?',
          sender: MessageSender.ai,
          timestamp: DateTime.now(),
        )
      ],
    );
  }
}

final chatNotifierProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
