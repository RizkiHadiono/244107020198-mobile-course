import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:week12_testing_quality_assurance/core/config/image_url_builder.dart';
import 'package:week12_testing_quality_assurance/features/announcements/data/datasources/announcement_remote_data_source.dart';
import 'package:week12_testing_quality_assurance/features/announcements/data/repositories/announcement_repository_impl.dart';

String _payload(int page, int limit) {
  return jsonEncode(
    List.generate(limit, (i) {
      final id = (page - 1) * limit + i + 1;
      return {
        'albumId': 1,
        'id': id,
        'title': 'pengumuman nomor $id',
        'url': 'https://example.com/$id.png',
        'thumbnailUrl': 'https://example.com/$id-thumb.png',
      };
    }),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AnnouncementRemoteDataSource', () {
    test('mengirim parameter pagination _page dan _limit', () async {
      late Uri captured;
      final client = MockClient((request) async {
        captured = request.url;
        final page = int.parse(request.url.queryParameters['_page'] ?? '1');
        final limit = int.parse(request.url.queryParameters['_limit'] ?? '20');
        return http.Response(_payload(page, limit), 200);
      });

      final remote = AnnouncementRemoteDataSource(client: client);
      final items = await remote.fetchPage(page: 2, limit: 20);

      expect(captured.queryParameters['_page'], '2');
      expect(captured.queryParameters['_limit'], '20');
      expect(items.length, 20);
      expect(items.first.id, 21);
      expect(items.first.title, 'Pengumuman Nomor 21');
    });

    test('memakai thumbnail/full URL dari ImageUrlBuilder', () async {
      final client = MockClient(
        (request) async => http.Response(_payload(1, 5), 200),
      );
      final remote = AnnouncementRemoteDataSource(
        client: client,
        images: const ImageUrlBuilder('http://127.0.0.1:8777/img'),
      );

      final items = await remote.fetchPage(page: 1, limit: 5);
      expect(items.first.imageUrl, 'http://127.0.0.1:8777/img/1200x800/1.png');
      expect(
        items.first.thumbnailUrl,
        'http://127.0.0.1:8777/img/150x100/1.png',
      );
    });

    test('HTTP error dilempar sebagai exception', () async {
      final client = MockClient(
        (request) async => http.Response('boom', 500),
      );
      final remote = AnnouncementRemoteDataSource(client: client);

      expect(
        () => remote.fetchPage(page: 1, limit: 20),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('AnnouncementRepositoryImpl (cache stale-while-revalidate)', () {
    test('menyimpan hasil jaringan ke cache lokal', () async {
      final client = MockClient(
        (request) async => http.Response(_payload(1, 20), 200),
      );
      final repo = AnnouncementRepositoryImpl(
        remote: AnnouncementRemoteDataSource(client: client),
      );

      await repo.fetchPage(page: 1, limit: 20);
      final cached = await repo.readCache();

      expect(cached.length, 20);
      expect(cached.first.id, 1);
    });

    test('readCache mengembalikan data yang tersimpan di SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'announcements_cache_v1',
        jsonEncode([
          {
            'id': 7,
            'title': 'Cache Lama',
            'body': 'isi',
            'category': 'Akademik',
            'imageUrl': 'a.png',
            'thumbnailUrl': 'b.png',
            'publishedAt': '2026-10-01T00:00:00.000',
          },
        ]),
      );

      final repo = AnnouncementRepositoryImpl();
      final cached = await repo.readCache();

      expect(cached.length, 1);
      expect(cached.first.title, 'Cache Lama');
    });

    test('fallback ke cache saat jaringan gagal (offline-first)', () async {
      // Isi cache dulu lewat request yang sukses.
      var offline = false;
      final client = MockClient((request) async {
        if (offline) return http.Response('offline', 503);
        return http.Response(_payload(1, 20), 200);
      });
      final repo = AnnouncementRepositoryImpl(
        remote: AnnouncementRemoteDataSource(client: client),
      );

      await repo.fetchPage(page: 1, limit: 20);
      offline = true;

      // Repository baru (memory cache kosong) harus tetap bisa membaca disk.
      final freshRepo = AnnouncementRepositoryImpl(
        remote: AnnouncementRemoteDataSource(client: client),
      );
      final result = await freshRepo.fetchPage(page: 1, limit: 20);

      expect(result.failure, isNull);
      expect(result.items.length, 20);
    });

    test('tanpa cache dan tanpa jaringan mengembalikan failure', () async {
      final client = MockClient(
        (request) async => http.Response('offline', 503),
      );
      final repo = AnnouncementRepositoryImpl(
        remote: AnnouncementRemoteDataSource(client: client),
      );

      final result = await repo.fetchPage(page: 1, limit: 20);
      expect(result.items, isEmpty);
      expect(result.failure, isNotNull);
    });

    test('clearCache menghapus cache lokal', () async {
      final client = MockClient(
        (request) async => http.Response(_payload(1, 5), 200),
      );
      final repo = AnnouncementRepositoryImpl(
        remote: AnnouncementRemoteDataSource(client: client),
      );

      await repo.fetchPage(page: 1, limit: 5);
      expect((await repo.readCache()).isNotEmpty, isTrue);

      await repo.clearCache();
      expect(await repo.readCache(), isEmpty);
    });
  });
}
