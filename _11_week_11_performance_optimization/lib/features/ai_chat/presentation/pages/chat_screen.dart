import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/perf/perf_recorder.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_providers.dart';

/// Layar chat Asisten AI (versi teroptimasi Week 11).
///
/// Perubahan performa dibanding baseline:
/// - daftar pesan dan indikator loading di-watch terpisah (`select`),
///   sehingga AppBar + kolom input tidak dibangun ulang setiap pesan masuk,
/// - setiap bubble dibungkus `RepaintBoundary`,
/// - `_ChatMessageBubble` menerima data primitif dan `const`-able,
/// - `ScrollController`/`TextEditingController` di-dispose dengan benar.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    // Filter privasi lokal: deteksi kemungkinan NIK / no rekening
    final nikRegex = RegExp(r'\b\d{16}\b');
    if (nikRegex.hasMatch(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Peringatan Privasi: Jangan mengirim data sensitif seperti 16 digit NIK ke AI API!',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _inputController.clear();
    ref.read(chatNotifierProvider.notifier).sendUserMessage(text);
    _scrollToBottom();
  }

  void _showFallbackDialog(String error) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Layanan AI Mengalami Kendala'),
          ],
        ),
        content: Text(
          'Tidak dapat memuat respon dari Gemini API.\n\n'
          'Penyebab: $error\n\n'
          'Saran:\n'
          '• Periksa koneksi internet Anda\n'
          '• Pastikan API Key valid di menu Pengaturan\n'
          '• Gunakan fitur Catatan secara offline',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/chat/settings');
            },
            child: const Text('Cek API Key'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Asisten Pintar POLINEMA',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Hapus Obrolan',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: ref.read(chatNotifierProvider.notifier).clearChat,
          ),
          IconButton(
            tooltip: 'Pengaturan API Key',
            icon: const Icon(Icons.key_outlined),
            onPressed: () => context.push('/chat/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          const _ApiKeyBanner(),
          Expanded(
            child: _ChatMessageList(
              scrollController: _scrollController,
              onShowError: _showFallbackDialog,
            ),
          ),
          const _TypingIndicator(),
          const Divider(height: 1),
          _ChatInputBar(
            controller: _inputController,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

/// Banner peringatan API key. Hanya bagian ini yang bergantung pada
/// `hasApiKeyProvider`.
class _ApiKeyBanner extends ConsumerWidget {
  const _ApiKeyBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasKey = ref.watch(hasApiKeyProvider.select((async) => async.value));
    if (hasKey != false) return const SizedBox.shrink();

    return MaterialBanner(
      backgroundColor: Colors.amber.shade100,
      leading: const Icon(Icons.key_off, color: Colors.amber),
      content: const Text(
        'API Key Gemini belum diset. Fitur AI membutuhkan Gemini API Key Anda.',
        style: TextStyle(fontSize: 13, color: Colors.black87),
      ),
      actions: [
        TextButton(
          onPressed: () => context.push('/chat/settings'),
          child: const Text('Atur Sekarang'),
        ),
      ],
    );
  }
}

/// Daftar pesan. `select` memastikan rebuild hanya terjadi ketika jumlah/isi
/// pesan berubah, bukan ketika `isLoading` berubah.
class _ChatMessageList extends ConsumerWidget {
  const _ChatMessageList({
    required this.scrollController,
    required this.onShowError,
  });

  final ScrollController scrollController;
  final void Function(String) onShowError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(
      chatNotifierProvider.select((s) => s.messages),
    );

    // Auto-scroll saat pesan bertambah (dijalankan sekali per perubahan list).
    ref.listen<List<ChatMessage>>(
      chatNotifierProvider.select((s) => s.messages),
      (previous, next) {
        if (previous?.length != next.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!scrollController.hasClients) return;
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          });
        }
      },
    );

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return RepaintBoundary(
          child: _ChatMessageBubble(
            key: ValueKey<String>(message.id),
            text: message.text,
            isUser: message.isUser,
            isSystem: message.isSystem,
            isError: message.isError,
            timeLabel: DateFormat('HH:mm').format(message.timestamp),
            onDetail: message.isError ? onShowError : null,
          ),
        );
      },
    );
  }
}

class _TypingIndicator extends ConsumerWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      chatNotifierProvider.select((s) => s.isLoading),
    );
    if (!isLoading) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Asisten AI sedang berpikir...',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatInputBar extends ConsumerWidget {
  const _ChatInputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      chatNotifierProvider.select((s) => s.isLoading),
    );
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: theme.scaffoldBackgroundColor,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Tanyakan sesuatu ke Asisten AI...',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withAlpha(80),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: isLoading ? null : onSend,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bubble pesan. Menerima data primitif agar tidak bergantung pada objek
/// entity dan bisa dibandingkan murah oleh framework.
class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    required this.isSystem,
    required this.isError,
    required this.timeLabel,
    this.onDetail,
  });

  final String text;
  final bool isUser;
  final bool isSystem;
  final bool isError;
  final String timeLabel;
  final void Function(String)? onDetail;

  @override
  Widget build(BuildContext context) {
    PerfRecorder.instance.countBuild('ChatMessageBubble');
    final theme = Theme.of(context);

    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      );
    }

    final bubbleColor = isError
        ? theme.colorScheme.errorContainer
        : isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.secondaryContainer;

    final textColor = isError
        ? theme.colorScheme.onErrorContainer
        : isUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSecondaryContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: isError
                  ? theme.colorScheme.error
                  : theme.colorScheme.secondary,
              child: Icon(
                isError ? Icons.error_outline : Icons.smart_toy,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                      if (isError && onDetail != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => onDetail!(text),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 12,
                                color: textColor,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Detail',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 18,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
