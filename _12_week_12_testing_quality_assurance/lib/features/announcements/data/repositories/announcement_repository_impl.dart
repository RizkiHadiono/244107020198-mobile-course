import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/failures.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../datasources/announcement_remote_data_source.dart';

/// Cache lokal berbasis `SharedPreferences`.
///
/// Dipisah dari repository agar bisa diuji tanpa jaringan.
class AnnouncementCacheStore {
  AnnouncementCacheStore({Future<SharedPreferences> Function()? getPrefs})
    : _getPrefs = getPrefs ?? SharedPreferences.getInstance;

  static const String _key = 'announcements_cache_v1';

  final Future<SharedPreferences> Function() _getPrefs;

  Future<List<Announcement>> read() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Announcement.fromJson(e as Map<String, Object?>))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> write(List<Announcement> items) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(
        _key,
        jsonEncode(items.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      // Cache bersifat best-effort; kegagalan menulis tidak boleh
      // menggagalkan alur utama.
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_key);
    } catch (_) {
      // abaikan
    }
  }
}

/// Strategi **stale-while-revalidate**:
/// 1. `readCache()` menampilkan data lama seketika (tanpa menunggu jaringan),
/// 2. `fetchPage()` mengambil data baru di latar belakang lalu memperbarui
///    cache,
/// 3. jika jaringan gagal dan cache tersedia, cache dipakai sebagai fallback.
class AnnouncementRepositoryImpl implements AnnouncementRepository {
  AnnouncementRepositoryImpl({
    AnnouncementRemoteDataSource? remote,
    AnnouncementCacheStore? cache,
  }) : _remote = remote ?? AnnouncementRemoteDataSource(),
       _cache = cache ?? AnnouncementCacheStore();

  final AnnouncementRemoteDataSource _remote;
  final AnnouncementCacheStore _cache;

  /// Cache dalam memori agar pembacaan berulang tidak menyentuh disk.
  List<Announcement>? _memoryCache;

  @override
  Future<({List<Announcement> items, Failure? failure})> fetchPage({
    required int page,
    required int limit,
    bool forceRefresh = false,
  }) async {
    try {
      final items = await _remote.fetchPage(page: page, limit: limit);

      final merged = _merge(
        existing: page == 1 ? const [] : (_memoryCache ?? const []),
        incoming: items,
      );
      _memoryCache = merged;
      await _cache.write(merged);

      return (items: items, failure: null);
    } catch (e) {
      // Fallback offline: tampilkan cache halaman yang diminta bila ada.
      final cached = _memoryCache ?? await _cache.read();
      if (cached.isNotEmpty) {
        _memoryCache = cached;
        final start = (page - 1) * limit;
        final end = (start + limit).clamp(0, cached.length);
        final slice = start >= cached.length
            ? const <Announcement>[]
            : cached.sublist(start, end);
        if (slice.isNotEmpty) {
          return (items: slice, failure: null);
        }
      }
      return (
        items: const <Announcement>[],
        failure: NetworkFailure('Gagal memuat pengumuman: $e'),
      );
    }
  }

  List<Announcement> _merge({
    required List<Announcement> existing,
    required List<Announcement> incoming,
  }) {
    final seen = <int>{};
    final merged = <Announcement>[];
    for (final item in [...existing, ...incoming]) {
      if (seen.add(item.id)) merged.add(item);
    }
    return merged;
  }

  @override
  Future<List<Announcement>> readCache() async {
    final cached = _memoryCache ?? await _cache.read();
    _memoryCache = cached;
    return cached;
  }

  @override
  Future<void> clearCache() async {
    _memoryCache = null;
    await _cache.clear();
  }
}
