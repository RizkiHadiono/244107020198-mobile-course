import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/format.dart';
import '../../../../core/perf/perf_recorder.dart';
import '../../../../core/perf/perf_scroll_registry.dart';
import '../../../../core/widgets/cached_thumbnail.dart';
import '../../domain/entities/announcement.dart';
import '../providers/announcements_providers.dart';

/// Halaman pengumuman kampus (versi teroptimasi Week 11).
///
/// Perubahan performa dibanding baseline:
/// - `ListView.builder` + pagination 20 item (baseline: 100 item sekaligus
///   dalam `SingleChildScrollView`),
/// - `CachedNetworkImage` dengan `memCacheWidth/Height` sehingga gambar
///   di-decode pada ukuran tampil, bukan 1200x800 (baseline),
/// - placeholder shimmer + error widget,
/// - `RepaintBoundary` per kartu agar scroll tidak me-repaint seluruh layar,
/// - cache stale-while-revalidate: data lama tampil instan, lalu diperbarui.
class AnnouncementsPage extends ConsumerStatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  ConsumerState<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends ConsumerState<AnnouncementsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (PerfRecorder.enabled) {
      PerfScrollRegistry.instance.register(_scrollController);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (PerfRecorder.enabled) {
      PerfScrollRegistry.instance.unregister(_scrollController);
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 500) {
      ref.read(announcementsNotifierProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      announcementsNotifierProvider.select((s) => s.isLoading),
    );
    final errorMessage = ref.watch(
      announcementsNotifierProvider.select((s) => s.errorMessage),
    );
    final fromCache = ref.watch(
      announcementsNotifierProvider.select((s) => s.fromCache),
    );
    final hasItems = ref.watch(
      announcementsNotifierProvider.select((s) => s.items.isNotEmpty),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengumuman Kampus'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(announcementsNotifierProvider.notifier).refresh(),
          ),
        ],
      ),
      body: isLoading && !hasItems
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null && !hasItems
          ? _AnnouncementsError(message: errorMessage)
          : Column(
              children: [
                if (fromCache)
                  const _OfflineBanner(),
                Expanded(
                  child: _AnnouncementsList(
                    controller: _scrollController,
                    hasMore: ref.watch(
                      announcementsNotifierProvider.select((s) => s.hasMore),
                    ),
                    isLoadingMore: ref.watch(
                      announcementsNotifierProvider.select(
                        (s) => s.isLoadingMore,
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Kembali',
        onPressed: () => context.pop(),
        child: const Icon(Icons.arrow_back),
      ),
    );
  }
}

class _AnnouncementsList extends ConsumerWidget {
  const _AnnouncementsList({
    required this.controller,
    required this.hasMore,
    required this.isLoadingMore,
  });

  final ScrollController controller;
  final bool hasMore;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(
      announcementsNotifierProvider.select((s) => s.items),
    );

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: items.length + (hasMore ? 1 : 0),
      findChildIndexCallback: (key) {
        final value = key is ValueKey<int> ? key.value : null;
        if (value == null) return null;
        final index = items.indexWhere((a) => a.id == value);
        return index == -1 ? null : index;
      },
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return _ListFooter(isLoading: isLoadingMore);
        }
        final item = items[index];
        return RepaintBoundary(
          child: AnnouncementCard(key: ValueKey<int>(item.id), item: item),
        );
      },
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.item});

  final Announcement item;

  @override
  Widget build(BuildContext context) {
    PerfRecorder.instance.countBuild('AnnouncementCard');
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Decode dibatasi ke ukuran tampil (358x180 logis @2x = 716x360 px)
          // sehingga memori gambar turun ~4x dibanding 1200x800.
          CachedThumbnail(
            url: item.imageUrl,
            height: 180,
            memWidth: 720,
            memHeight: 360,
            placeholder: (context) => const _ImagePlaceholder(),
            errorWidget: (context) => const _ImageError(),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardMeta(item: item),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardMeta extends StatelessWidget {
  const _CardMeta({required this.item});

  final Announcement item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            item.category,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const Spacer(),
        Text(
          formatDate(item.publishedAt),
          style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
        ),
      ],
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(height: 180, color: Colors.white),
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: Colors.black87),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Menampilkan data dari cache lokal. Menyegarkan dari server...',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(
                'Gulir untuk memuat lebih banyak',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
      ),
    );
  }
}

class _AnnouncementsError extends StatelessWidget {
  const _AnnouncementsError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
