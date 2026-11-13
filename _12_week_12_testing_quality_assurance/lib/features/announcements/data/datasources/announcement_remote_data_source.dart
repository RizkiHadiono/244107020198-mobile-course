import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/image_url_builder.dart';
import '../../domain/entities/announcement.dart';

class AnnouncementRemoteDataSource {
  AnnouncementRemoteDataSource({
    http.Client? client,
    this.images = const ImageUrlBuilder(ImageUrlBuilder.defaultBase),
    this.endpoint = defaultEndpoint,
  }) : _client = client ?? http.Client();

  static const String defaultEndpoint =
      'https://jsonplaceholder.typicode.com/photos';

  final http.Client _client;
  final ImageUrlBuilder images;
  final String endpoint;

  /// Mengambil satu halaman. Pagination dikerjakan server lewat `_page` dan
  /// `_limit` sehingga payload yang diunduh sebanding dengan yang ditampilkan.
  Future<List<Announcement>> fetchPage({
    required int page,
    required int limit,
  }) async {
    final uri = Uri.parse('$endpoint?_page=$page&_limit=$limit');
    final response = await _client
        .get(uri, headers: {'Accept-Encoding': 'gzip'})
        .timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw Exception('Waktu permintaan habis (timeout)'),
        );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} saat memuat pengumuman');
    }

    final raw = jsonDecode(response.body) as List<dynamic>;
    return raw
        .map((e) => _toAnnouncement(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Announcement _toAnnouncement(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final albumId = (json['albumId'] as num?)?.toInt() ?? 0;
    return Announcement(
      id: id,
      title: _titleCase(json['title'] as String? ?? 'Pengumuman Kampus'),
      body: _bodyFor(id),
      category: _categories[albumId % _categories.length],
      imageUrl: images.full(id),
      thumbnailUrl: images.thumb(id),
      publishedAt: DateTime(
        2026,
        11,
        1,
      ).subtract(Duration(hours: id * 3)),
    );
  }

  static const List<String> _categories = [
    'Akademik',
    'Kemahasiswaan',
    'Beasiswa',
    'Umum',
  ];

  static const List<String> _bodies = [
    'Seluruh mahasiswa diharapkan memperhatikan jadwal terbaru dan menghubungi '
        'dosen pembimbing akademik apabila terdapat benturan jadwal.',
    'Berkas pendaftaran dapat diunggah melalui portal akademik paling lambat '
        'akhir pekan ini. Berkas yang terlambat tidak diproses.',
    'Kegiatan dilaksanakan di Gedung Teknologi Informasi lantai 3. Peserta '
        'wajib membawa kartu tanda mahasiswa.',
    'Informasi lengkap dan dokumen pendukung tersedia pada laman resmi '
        'jurusan. Silakan membaca dengan saksama sebelum mengajukan.',
    'Bagi mahasiswa yang memenuhi kriteria, silakan melengkapi formulir dan '
        'surat rekomendasi dari ketua program studi.',
  ];

  static String _bodyFor(int id) => _bodies[id % _bodies.length];

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
