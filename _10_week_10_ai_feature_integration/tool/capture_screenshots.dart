// Tool pembuat screenshot dokumentasi untuk Laporan Praktikum Week 10.
//
// Bukan unit test — jalankan manual saat dokumentasi perlu diperbarui:
//   flutter test tool/capture_screenshots.dart
//
// Hasil tersimpan di folder `screenshots/`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:week10_ai_feature_integration/features/ai_chat/domain/entities/chat_message.dart';
import 'package:week10_ai_feature_integration/features/ai_chat/domain/repositories/ai_repository.dart';
import 'package:week10_ai_feature_integration/features/ai_chat/presentation/pages/api_key_settings.dart';
import 'package:week10_ai_feature_integration/features/ai_chat/presentation/pages/chat_screen.dart';
import 'package:week10_ai_feature_integration/features/ai_chat/presentation/providers/chat_providers.dart';
import 'package:week10_ai_feature_integration/features/auth/domain/entities/user.dart';
import 'package:week10_ai_feature_integration/features/auth/presentation/providers/auth_providers.dart';
import 'package:week10_ai_feature_integration/features/notes/domain/entities/note.dart';
import 'package:week10_ai_feature_integration/features/notes/presentation/pages/notes_page.dart';
import 'package:week10_ai_feature_integration/features/notes/presentation/providers/notes_providers.dart';

/// Memuat font asli dari Flutter SDK agar teks tidak dirender sebagai kotak (Ahem).
Future<void> _loadRealFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    throw StateError('FLUTTER_ROOT tidak tersedia. Jalankan lewat `flutter test`.');
  }
  final fontDir = Directory('$flutterRoot/bin/cache/artifacts/material_fonts');

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = await File('${fontDir.path}/$file').readAsBytes();
      loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
    }
    await loader.load();
  }

  await load('Roboto', [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
  ]);
  await load('MaterialIcons', ['materialicons-regular.otf']);
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String filename) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;

    final dir = Directory('screenshots');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('screenshots/$filename').writeAsBytesSync(data.buffer.asUint8List());
  });
}

/// Tema identik dengan `lib/main.dart` agar screenshot merepresentasikan aplikasi asli.
ThemeData _appTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
      fontFamily: 'Roboto',
    );

void main() {
  setUpAll(_loadRealFonts);

  Future<GlobalKey> pumpPage(WidgetTester tester, Widget page, List<Override> overrides) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _appTheme(),
            home: page,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return key;
  }

  testWidgets('01 - Halaman Catatan dengan akses Asisten AI', (tester) async {
    final key = await pumpPage(
      tester,
      const NotesPage(),
      [
        authStateProvider.overrideWith(_FakeAuthNotifier.new),
        notesNotifierProvider.overrideWith(_FakeNotesNotifier.new),
        dirtyNotesCountProvider.overrideWith((ref) async => 0),
      ],
    );
    await _capture(tester, key, 'screenshot-01-notes-page-ai-button.png');
  });

  testWidgets('02 - Percakapan Asisten AI', (tester) async {
    final key = await pumpPage(
      tester,
      const ChatScreen(),
      [
        hasApiKeyProvider.overrideWith((ref) async => true),
        chatNotifierProvider.overrideWith(_FakeChatNotifier.new),
      ],
    );
    await _capture(tester, key, 'screenshot-02-chat-screen-conversation.png');
  });

  testWidgets('03 - Pengaturan API Key', (tester) async {
    final key = await pumpPage(
      tester,
      const ApiKeySettingsPage(),
      [aiRepositoryProvider.overrideWithValue(_FakeAiRepository())],
    );
    await _capture(tester, key, 'screenshot-03-api-key-settings.png');
  });

  testWidgets('04 - Peringatan privasi NIK diblokir', (tester) async {
    final key = await pumpPage(
      tester,
      const ChatScreen(),
      [
        hasApiKeyProvider.overrideWith((ref) async => true),
        chatNotifierProvider.overrideWith(_FakeChatNotifier.new),
      ],
    );

    await tester.enterText(find.byType(TextField), 'NIK saya 3507041234560001');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await _capture(tester, key, 'screenshot-04-privacy-guard-nik.png');
  });

  testWidgets('05 - Fallback saat layanan AI gagal', (tester) async {
    final key = await pumpPage(
      tester,
      const ChatScreen(),
      [
        hasApiKeyProvider.overrideWith((ref) async => true),
        chatNotifierProvider.overrideWith(_FakeChatNotifier.new),
      ],
    );

    // Picu dialog fallback dari bubble error.
    await tester.tap(find.text('Detail'));
    await tester.pumpAndSettle();

    await _capture(tester, key, 'screenshot-05-fallback-dialog.png');
  });
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        user: User(
          id: '1',
          name: 'Mokhamad Rizki',
          email: '244107020198@polinema.ac.id',
        ),
      );
}

class _FakeNotesNotifier extends NotesNotifier {
  @override
  NotesState build() => NotesState(
        notes: [
          Note(
            id: 1,
            title: 'Rangkuman Arsitektur Clean',
            body: 'Domain murni Dart, data & presentation terpisah.',
            updatedAt: DateTime(2026, 11, 1, 8, 15),
          ),
          Note(
            id: 2,
            title: 'Tugas Besar Pemrograman Mobile',
            body: 'Integrasi fitur AI + laporan praktikum Week 10.',
            updatedAt: DateTime(2026, 10, 30, 16, 40),
          ),
          Note(
            id: 3,
            title: 'Jadwal UTS TI-3G',
            body: 'Senin: Pemrograman Mobile, Rabu: Basis Data.',
            updatedAt: DateTime(2026, 10, 28, 10, 5),
          ),
        ],
      );
}

class _FakeChatNotifier extends ChatNotifier {
  @override
  ChatState build() => ChatState(
        messages: [
          ChatMessage(
            id: '1',
            text: 'Halo! Saya Asisten Pintar POLINEMA. Ada yang bisa saya bantu '
                'seputar perkuliahan, jadwal, atau tugas?',
            sender: MessageSender.ai,
            timestamp: DateTime(2026, 11, 1, 9, 41),
          ),
          ChatMessage(
            id: '2',
            text: 'Bagaimana cara mengajukan dispensasi sakit di kampus?',
            sender: MessageSender.user,
            timestamp: DateTime(2026, 11, 1, 9, 42),
          ),
          ChatMessage(
            id: '3',
            text: 'Untuk mengajukan dispensasi sakit di POLINEMA, siapkan surat '
                'keterangan dokter asli lalu serahkan ke DPA atau admin jurusan '
                'maksimal 3 hari kerja setelah kembali sehat. Pastikan juga '
                'presensi diperbarui melalui SIAKAD.',
            sender: MessageSender.ai,
            timestamp: DateTime(2026, 11, 1, 9, 42),
          ),
          ChatMessage(
            id: '4',
            text: 'Layanan AI sedang sibuk (HTTP 429). Coba lagi beberapa saat '
                'lagi atau gunakan mode offline.',
            sender: MessageSender.ai,
            timestamp: DateTime(2026, 11, 1, 9, 43),
            isError: true,
          ),
        ],
      );
}

class _FakeAiRepository implements AiRepository {
  @override
  Future<String?> getApiKey() async => 'AIzaSyD9xQ2mK7pL4vN8rT1wZ3bY6cH0aF5eJ2uX';

  @override
  Future<void> saveApiKey(String key) async {}

  @override
  Future<void> removeApiKey() async {}

  @override
  Future<ChatMessage> sendMessage(
    String text, {
    List<ChatMessage> history = const [],
  }) async =>
      ChatMessage(
        id: 'resp',
        text: 'Jawaban AI',
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      );
}
