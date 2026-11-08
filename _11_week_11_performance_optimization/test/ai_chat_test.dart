import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:week11_performance_optimization/features/ai_chat/data/datasources/ai_service.dart';
import 'package:week11_performance_optimization/features/ai_chat/data/repositories/ai_repository_impl.dart';
import 'package:week11_performance_optimization/features/ai_chat/domain/entities/chat_message.dart';
import 'package:week11_performance_optimization/features/ai_chat/domain/usecases/send_message.dart';

// Fake FlutterSecureStorage untuk testing in-memory
class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _storage[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }
}

void main() {
  group('AiService Tests', () {
    late FakeSecureStorage fakeStorage;

    setUp(() {
      fakeStorage = FakeSecureStorage();
    });

    test('melemparkan AiServiceException jika API Key kosong', () async {
      final service = AiService(storage: fakeStorage);

      expect(
        () => service.ask('Halo'),
        throwsA(isA<AiServiceException>().having(
          (e) => e.message,
          'message',
          contains('API key belum diatur'),
        )),
      );
    });

    test('berhasil memanggil AI API saat status code 200', () async {
      await fakeStorage.write(key: 'ai_api_key', value: 'fake_key_123');

      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['key'], 'fake_key_123');
        final responsePayload = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Halo! Saya asisten kampus siap membantu.'}
                ]
              }
            }
          ]
        };
        return http.Response(jsonEncode(responsePayload), 200, headers: {
          'content-type': 'application/json',
        });
      });

      final service = AiService(storage: fakeStorage, client: mockClient);
      final result = await service.ask('Halo');

      expect(result, 'Halo! Saya asisten kampus siap membantu.');
    });

    test('menangani error 400/403 dari Gemini API dengan pesan ramah', () async {
      await fakeStorage.write(key: 'ai_api_key', value: 'invalid_key');

      final mockClient = MockClient((request) async {
        return http.Response('Invalid API Key', 400);
      });

      final service = AiService(storage: fakeStorage, client: mockClient);

      expect(
        () => service.ask('Test'),
        throwsA(isA<AiServiceException>().having(
          (e) => e.message,
          'message',
          contains('API Key tidak valid'),
        )),
      );
    });

    test('menangani rate limit 429 dengan pesan yang tepat', () async {
      await fakeStorage.write(key: 'ai_api_key', value: 'valid_key');

      final mockClient = MockClient((request) async {
        return http.Response('Quota exceeded', 429);
      });

      final service = AiService(storage: fakeStorage, client: mockClient);

      expect(
        () => service.ask('Test'),
        throwsA(isA<AiServiceException>().having(
          (e) => e.message,
          'message',
          contains('Rate limit'),
        )),
      );
    });
  });

  group('AiRepository & UseCase Tests', () {
    late FakeSecureStorage fakeStorage;

    setUp(() {
      fakeStorage = FakeSecureStorage();
    });

    test('SendMessageUseCase melempar ArgumentError jika pesan kosong', () async {
      final repo = AiRepositoryImpl(aiService: AiService(storage: fakeStorage));
      final useCase = SendMessageUseCase(repo);

      expect(() => useCase('   '), throwsA(isA<ArgumentError>()));
    });

    test('AiRepository mengembalikan ChatMessage bertanda isError saat terjadi exception', () async {
      // Tanpa simpan API key -> error
      final repo = AiRepositoryImpl(aiService: AiService(storage: fakeStorage));
      final result = await repo.sendMessage('Halo AI');

      expect(result.isError, isTrue);
      expect(result.sender, MessageSender.ai);
      expect(result.text, contains('API key belum diatur'));
    });

    test('AiRepository mengembalikan ChatMessage sukses saat respons valid', () async {
      await fakeStorage.write(key: 'ai_api_key', value: 'my_test_key');

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Ini adalah jawaban kampus.'}
                  ]
                }
              }
            ]
          }),
          200,
        );
      });

      final service = AiService(storage: fakeStorage, client: mockClient);
      final repo = AiRepositoryImpl(aiService: service);
      final useCase = SendMessageUseCase(repo);

      final message = await useCase('Pertanyaan valid');

      expect(message.isError, isFalse);
      expect(message.sender, MessageSender.ai);
      expect(message.text, 'Ini adalah jawaban kampus.');
    });
  });
}
