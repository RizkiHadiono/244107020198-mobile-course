import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AiServiceException implements Exception {
  final String message;
  final int? statusCode;

  AiServiceException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class AiService {
  final FlutterSecureStorage _storage;
  final http.Client _client;

  // Menggunakan Gemini 2.5 Flash / 1.5 Flash sebagai endpoint standar Google AI Studio
  static const String defaultEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  static const String systemInstruction =
      'Kamu adalah asisten kampus ramah untuk mahasiswa Politeknik Negeri Malang (POLINEMA). '
      'Jawab dalam Bahasa Indonesia secara ringkas, jelas, sopan, dan solutif (maksimal 3-4 kalimat). '
      'Jangan pernah meminta atau membocorkan data pribadi sensitif seperti NIK, password, atau nomor rekening.';

  AiService({
    FlutterSecureStorage? storage,
    http.Client? client,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client();

  Future<String?> getApiKey() async {
    return await _storage.read(key: 'ai_api_key');
  }

  Future<void> saveApiKey(String key) async {
    await _storage.write(key: 'ai_api_key', value: key.trim());
  }

  Future<void> removeApiKey() async {
    await _storage.delete(key: 'ai_api_key');
  }

  Future<String> ask(
    String question, {
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw AiServiceException(
        'API key belum diatur. Silakan atur Gemini API Key Anda di menu Pengaturan API Key.',
      );
    }

    // Bangun payload dengan riwayat percakapan + system context
    final contents = <Map<String, dynamic>>[];

    for (final msg in conversationHistory) {
      contents.add({
        'role': msg['role'] == 'user' ? 'user' : 'model',
        'parts': [
          {'text': msg['text'] ?? ''}
        ],
      });
    }

    // Tambahkan input terkini user
    contents.add({
      'role': 'user',
      'parts': [
        {'text': question}
      ],
    });

    final requestBody = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 500,
      }
    });

    try {
      final response = await _client.post(
        Uri.parse('$defaultEndpoint?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates == null || candidates.isEmpty) {
          throw AiServiceException('Model tidak memberikan balasan.');
        }

        final content = candidates[0]['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts == null || parts.isEmpty) {
          throw AiServiceException('Format respons tidak terduga dari AI.');
        }

        final text = parts[0]['text'] as String?;
        return text?.trim() ?? 'Tidak ada jawaban.';
      } else if (response.statusCode == 400 || response.statusCode == 403) {
        throw AiServiceException(
          'API Key tidak valid atau limit terlampaui. Periksa kembali kunci Anda di Google AI Studio.',
          response.statusCode,
        );
      } else if (response.statusCode == 429) {
        throw AiServiceException(
          'Terlalu banyak permintaan (Rate limit). Tunggu beberapa saat sebelum mencoba lagi.',
          response.statusCode,
        );
      } else {
        throw AiServiceException(
          'Gagal memanggil AI API: HTTP ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is AiServiceException) rethrow;
      throw AiServiceException(
        'Koneksi gagal atau layanan AI tidak merespons: $e',
      );
    }
  }
}
