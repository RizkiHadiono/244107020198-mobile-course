import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format.dart';
import '../../../../core/perf/perf_recorder.dart';
import '../../../../core/perf/perf_scroll_registry.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/note.dart';
import '../providers/notes_providers.dart';

/// Halaman daftar catatan (versi teroptimasi Week 11).
///
/// Perubahan performa dibanding baseline:
/// - `ref.watch(...select(...))` pada potongan state yang sempit, sehingga
///   mengetik di kolom pencarian tidak membangun ulang AppBar/FAB,
/// - `ListView.builder` + pagination 20 item (bukan seluruh isi tabel),
/// - item dipecah menjadi widget `const`-able dengan `RepaintBoundary`,
/// - closure `onTap`/`onDelete` di-hoist ke method (bukan dibuat per build).
class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listController = ScrollController();

  @override
  void initState() {
    super.initState();
    _listController.addListener(_onScroll);
    if (PerfRecorder.enabled) {
      PerfScrollRegistry.instance.register(_listController);
      PerfScrollRegistry.instance.registerSearch(_searchController);
    }
  }

  @override
  void dispose() {
    _listController.removeListener(_onScroll);
    if (PerfRecorder.enabled) {
      PerfScrollRegistry.instance.unregister(_listController);
      PerfScrollRegistry.instance.unregisterSearch(_searchController);
    }
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  /// Infinite scroll: minta halaman berikutnya 400 px sebelum ujung daftar.
  void _onScroll() {
    if (!_listController.hasClients) return;
    final position = _listController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(notesNotifierProvider.notifier).loadMore();
    }
  }

  void _openNote(Note note) {
    context.push('/notes/${note.id}', extra: note);
  }

  Future<void> _deleteNote(Note note) async {
    if (note.id == null) return;
    await ref.read(notesNotifierProvider.notifier).delete(note.id!);
  }

  void _showAddNoteDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Buat Catatan Baru',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Judul',
                    hintText: 'Mis. Pertemuan Arsitektur',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Isi Catatan',
                    hintText: 'Tulis ringkasan atau detail...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text;
                final body = bodyController.text;
                final messenger = ScaffoldMessenger.of(context);
                final errorColor = Theme.of(context).colorScheme.error;
                final success = await ref
                    .read(notesNotifierProvider.notifier)
                    .add(title: title, body: body);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (!success) {
                  final err =
                      ref.read(notesNotifierProvider).errorMessage ??
                      'Gagal membuat catatan';
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(err),
                      backgroundColor: errorColor,
                    ),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _NotesAppBar(
        onSync: () => ref.read(notesNotifierProvider.notifier).sync(),
        onLogout: () async {
          await ref.read(authStateProvider.notifier).logout();
          if (context.mounted) context.go('/login');
        },
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notesNotifierProvider.notifier).loadNotes(),
        child: _NotesBody(
          searchController: _searchController,
          listController: _listController,
          onOpenNote: _openNote,
          onDeleteNote: _deleteNote,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddNoteDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Catatan Baru'),
      ),
    );
  }
}

/// AppBar dipisah + `const`-able: tidak ikut dibangun ulang saat daftar berubah.
class _NotesAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _NotesAppBar({required this.onSync, required this.onLogout});

  final Future<bool> Function() onSync;
  final Future<void> Function() onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `select` agar perubahan jumlah antrean sinkron tidak membangun ulang
    // seluruh AppBar.
    final dirtyCount = ref.watch(
      dirtyNotesCountProvider.select((async) => async.asData?.value ?? 0),
    );
    final user = ref.watch(authStateProvider.select((s) => s.user));
    final isLoading = ref.watch(
      notesNotifierProvider.select((s) => s.isLoading),
    );

    return AppBar(
      title: _NotesTitle(userName: user?.name, userEmail: user?.email),
      actions: [
        IconButton(
          tooltip: 'Pengumuman Kampus',
          icon: const Icon(Icons.campaign_outlined),
          onPressed: () => context.push('/announcements'),
        ),
        IconButton(
          tooltip: 'Asisten Pintar AI',
          icon: const Icon(Icons.smart_toy_outlined),
          onPressed: () => context.push('/chat'),
        ),
        IconButton(
          tooltip: 'Sinkronisasi Cloud',
          icon: Badge(
            isLabelVisible: dirtyCount != 0,
            label: Text('$dirtyCount'),
            child: const Icon(Icons.cloud_sync_outlined),
          ),
          onPressed: () async {
            await onSync();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ref.read(notesNotifierProvider).errorMessage ??
                      'Sinkronisasi berhasil! Seluruh antrean terkirim.',
                ),
              ),
            );
          },
        ),
        IconButton(
          tooltip: 'Keluar',
          icon: const Icon(Icons.logout_rounded),
          onPressed: onLogout,
        ),
      ],
      bottom: isLoading
          ? const PreferredSize(
              preferredSize: Size.fromHeight(2),
              child: LinearProgressIndicator(minHeight: 2),
            )
          : null,
    );
  }
}

class _NotesTitle extends StatelessWidget {
  const _NotesTitle({this.userName, this.userEmail});

  final String? userName;
  final String? userEmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Catatan Mandiri',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        if (userName != null)
          Text(
            'Halo, $userName ($userEmail)',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Bagian isi: header pencarian + daftar.
///
/// `Consumer` dipersempit ke bagian yang benar-benar berubah agar AppBar dan
/// FAB di atasnya tidak ikut di-rebuild.
class _NotesBody extends ConsumerWidget {
  const _NotesBody({
    required this.searchController,
    required this.listController,
    required this.onOpenNote,
    required this.onDeleteNote,
  });

  final TextEditingController searchController;
  final ScrollController listController;
  final void Function(Note) onOpenNote;
  final Future<void> Function(Note) onDeleteNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      notesNotifierProvider.select((s) => s.isLoading),
    );
    final errorMessage = ref.watch(
      notesNotifierProvider.select((s) => s.errorMessage),
    );
    final total = ref.watch(notesNotifierProvider.select((s) => s.total));
    final hasMore = ref.watch(notesNotifierProvider.select((s) => s.hasMore));
    final isLoadingMore = ref.watch(
      notesNotifierProvider.select((s) => s.isLoadingMore),
    );
    final query = ref.watch(notesNotifierProvider.select((s) => s.searchQuery));

    if (isLoading && total == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null && total == 0) {
      return _ErrorState(
        message: errorMessage,
        onRetry: () => ref.read(notesNotifierProvider.notifier).loadNotes(),
      );
    }

    return Column(
      children: [
        _SearchField(controller: searchController),
        Expanded(
          child: _NotesList(
            listController: listController,
            query: query,
            hasMore: hasMore,
            isLoadingMore: isLoadingMore,
            onOpenNote: onOpenNote,
            onDeleteNote: onDeleteNote,
          ),
        ),
      ],
    );
  }
}

class _SearchField extends ConsumerWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        key: const Key('notesSearchField'),
        controller: controller,
        onChanged: ref.read(notesNotifierProvider.notifier).setSearchQuery,
        decoration: InputDecoration(
          hintText: 'Cari judul catatan...',
          prefixIcon: const Icon(Icons.search_rounded),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
        ),
      ),
    );
  }
}

class _NotesList extends ConsumerWidget {
  const _NotesList({
    required this.listController,
    required this.query,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onOpenNote,
    required this.onDeleteNote,
  });

  final ScrollController listController;
  final String query;
  final bool hasMore;
  final bool isLoadingMore;
  final void Function(Note) onOpenNote;
  final Future<void> Function(Note) onDeleteNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hanya daftar terfilter yang di-watch di sini.
    final visible = ref.watch(visibleNotesProvider);
    final isSearching = query.trim().isNotEmpty;

    if (visible.isEmpty) {
      return _EmptyState(isSearching: isSearching, query: query);
    }

    // Saat mencari, tidak perlu footer pagination.
    final extra = isSearching ? 0 : (hasMore ? 1 : 0);

    return ListView.builder(
      controller: listController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: visible.length + extra,
      // Membantu Flutter mempertahankan state item saat daftar bertambah.
      findChildIndexCallback: (key) {
        final value = key is ValueKey<int> ? key.value : null;
        if (value == null) return null;
        final index = visible.indexWhere((n) => n.id == value);
        return index == -1 ? null : index;
      },
      itemBuilder: (context, index) {
        if (index >= visible.length) {
          return _PaginationFooter(isLoading: isLoadingMore);
        }
        final note = visible[index];
        return RepaintBoundary(
          child: NoteCard(
            key: ValueKey<int>(note.id ?? index),
            note: note,
            onTap: onOpenNote,
            onDelete: onDeleteNote,
          ),
        );
      },
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isSearching, required this.query});

  final bool isSearching;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('notesSearchEmptyState'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching ? Icons.search_off_rounded : Icons.note_alt_outlined,
              size: isSearching ? 72 : 80,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              isSearching ? 'Tidak ada catatan yang cocok' : 'Belum ada catatan',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isSearching) ...[
              const SizedBox(height: 6),
              Text(
                'Coba kata kunci lain untuk "${query.trim()}".',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'Tekan tombol di bawah untuk menambahkan catatan pertama.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu catatan. `const`-able dan tidak menyimpan closure per-item.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final void Function(Note) onTap;
  final Future<void> Function(Note) onDelete;

  @override
  Widget build(BuildContext context) {
    PerfRecorder.instance.countBuild('NoteCard');
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(note.id ?? note.title),
      direction: DismissDirection.endToStart,
      background: _DeleteBackground(theme: theme),
      onDismissed: (_) => onDelete(note),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () => onTap(note),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NoteCardHeader(note: note),
                if (note.body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    note.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _NoteCardFooter(updatedAt: note.updatedAt),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteCardHeader extends StatelessWidget {
  const _NoteCardHeader({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            note.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        if (note.dirty) const _UnsyncedBadge(),
      ],
    );
  }
}

class _UnsyncedBadge extends StatelessWidget {
  const _UnsyncedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 14,
            color: Colors.orange.shade900,
          ),
          const SizedBox(width: 4),
          Text(
            'Unsynced',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCardFooter extends StatelessWidget {
  const _NoteCardFooter({required this.updatedAt});

  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          formatDate(updatedAt),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: theme.colorScheme.outline,
        ),
      ],
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: Icon(
        Icons.delete_outline_rounded,
        color: theme.colorScheme.onErrorContainer,
      ),
    );
  }
}
