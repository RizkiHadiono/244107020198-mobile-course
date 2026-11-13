import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/image_url_builder.dart';
import '../../data/datasources/announcement_remote_data_source.dart';
import '../../data/repositories/announcement_repository_impl.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../../domain/usecases/get_announcements.dart';

/// Ukuran satu halaman pengumuman.
const int kAnnouncementsPageSize = 20;

/// Basis URL gambar; di-override oleh harness profiling ke server lokal.
final imageUrlBuilderProvider = Provider<ImageUrlBuilder>((ref) {
  return const ImageUrlBuilder(
    String.fromEnvironment(
      'PERF_IMAGE_BASE',
      defaultValue: ImageUrlBuilder.defaultBase,
    ),
  );
});

final announcementRemoteProvider = Provider<AnnouncementRemoteDataSource>((ref) {
  return AnnouncementRemoteDataSource(
    images: ref.watch(imageUrlBuilderProvider),
  );
});

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepositoryImpl(
    remote: ref.watch(announcementRemoteProvider),
  );
});

final getAnnouncementsProvider = Provider<GetAnnouncements>((ref) {
  return GetAnnouncements(ref.watch(announcementRepositoryProvider));
});

class AnnouncementsState {
  const AnnouncementsState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
    this.fromCache = false,
  });

  final List<Announcement> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;

  /// True saat daftar berasal dari cache lokal (belum/tidak terhubung server).
  final bool fromCache;

  AnnouncementsState copyWith({
    List<Announcement>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    bool? fromCache,
  }) {
    return AnnouncementsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}

class AnnouncementsNotifier extends Notifier<AnnouncementsState> {
  int _page = 0;

  @override
  AnnouncementsState build() {
    state = const AnnouncementsState(isLoading: true);
    // Cache-first: tampilkan data lokal segera, lalu revalidate ke server.
    _loadFromCacheThenRefresh();
    return state;
  }

  Future<void> _loadFromCacheThenRefresh() async {
    final cached = await ref.read(announcementRepositoryProvider).readCache();
    if (cached.isNotEmpty) {
      state = state.copyWith(
        items: cached.take(kAnnouncementsPageSize).toList(),
        isLoading: false,
        fromCache: true,
        hasMore: cached.length >= kAnnouncementsPageSize,
      );
      _page = 1;
    }
    await refresh();
  }

  /// Muat ulang halaman pertama (pull-to-refresh / tombol refresh).
  Future<void> refresh() async {
    if (state.isLoading && state.items.isEmpty) {
      // sudah menampilkan indikator awal
    } else {
      state = state.copyWith(isLoading: state.items.isEmpty);
    }

    final result = await ref.read(getAnnouncementsProvider)(
      page: 1,
      limit: kAnnouncementsPageSize,
      forceRefresh: true,
    );

    if (result.failure != null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: state.items.isEmpty ? result.failure!.message : null,
      );
      return;
    }

    _page = 1;
    state = state.copyWith(
      items: result.items,
      isLoading: false,
      hasMore: result.items.length == kAnnouncementsPageSize,
      fromCache: false,
    );
  }

  /// Infinite scroll.
  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    final nextPage = _page + 1;
    final result = await ref.read(getAnnouncementsProvider)(
      page: nextPage,
      limit: kAnnouncementsPageSize,
    );

    if (result.failure != null) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: result.failure!.message,
      );
      return;
    }

    if (result.items.isEmpty) {
      state = state.copyWith(isLoadingMore: false, hasMore: false);
      return;
    }

    _page = nextPage;
    state = state.copyWith(
      items: [...state.items, ...result.items],
      isLoadingMore: false,
      hasMore: result.items.length == kAnnouncementsPageSize,
    );
  }
}

final announcementsNotifierProvider =
    NotifierProvider<AnnouncementsNotifier, AnnouncementsState>(
      AnnouncementsNotifier.new,
    );
