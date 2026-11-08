import '../../../../core/failures.dart';
import '../entities/announcement.dart';

abstract class AnnouncementRepository {
  /// Mengambil satu halaman pengumuman dari jaringan, lalu menyimpannya ke
  /// cache lokal (stale-while-revalidate).
  Future<({List<Announcement> items, Failure? failure})> fetchPage({
    required int page,
    required int limit,
    bool forceRefresh = false,
  });

  /// Membaca cache lokal tanpa menyentuh jaringan (offline-first).
  Future<List<Announcement>> readCache();

  /// Menghapus cache lokal.
  Future<void> clearCache();
}
