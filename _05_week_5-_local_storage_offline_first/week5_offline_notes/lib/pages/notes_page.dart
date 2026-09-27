import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/note_repository.dart';
import '../data/local/note.dart';
import '../data/sync.dart';
import '../data/prefs.dart'; 
import 'widgets/note_tile.dart';

class ForceOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle(bool value) => state = value;
}

final forceOfflineProvider = NotifierProvider<ForceOfflineNotifier, bool>(ForceOfflineNotifier.new);
final noteRepositoryProvider = Provider((ref) => NoteRepository());

final notesProvider = FutureProvider<List<Note>>((ref) async {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.fetchNotes();
});

final dirtyCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.countDirty();
});

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => 
      ref.read(prefsRepositoryProvider).saveLastOpenedTime()
    );
  }

  Future<void> _performSync(bool isOffline) async {
    try {
      final syncService = SyncService(Dio());
      final repo = ref.read(noteRepositoryProvider);
      await syncService.syncNotes(repo, isOffline);
      ref.invalidate(dirtyCountProvider); 
      ref.invalidate(notesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sinkronisasi berhasil!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);
    final dirtyCountAsync = ref.watch(dirtyCountProvider);
    final isOffline = ref.watch(forceOfflineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Notes'),
        actions: [
          dirtyCountAsync.when(
            data: (count) => count > 0 
                ? Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Center(
                      child: Badge(
                        label: Text(count.toString()),
                        child: const Icon(Icons.cloud_off, color: Colors.orange),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: isOffline ? Colors.red.withValues(alpha: 0.1) : Colors.transparent,
            child: SwitchListTile(
              title: const Text('Mode Pesawat (Simulasi)'),
              subtitle: Text(isOffline ? 'Offline - Perubahan akan masuk antrean' : 'Online - Terhubung ke server'),
              value: isOffline,
              activeThumbColor: Colors.red,
              onChanged: (value) => ref.read(forceOfflineProvider.notifier).toggle(value),
            ),
          ),
          
          // Tombol Sync dimunculkan kembali di sini
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FilledButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text('Sync Notes'),
              onPressed: () => _performSync(isOffline),
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _performSync(isOffline),
              child: notesAsync.when(
                data: (notes) {
                  if (notes.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(child: Text('Belum ada catatan.\nTarik ke bawah atau tekan Sync.', textAlign: TextAlign.center)),
                      ],
                    );
                  }
                  return ListView.separated(
                    itemCount: notes.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) => NoteTile(note: notes[index]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              ),
            ),
          ),
        ],
      ),
floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final titleController = TextEditingController();
          final bodyController = TextEditingController();

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Buat Catatan Baru'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Judul'),
                  ),
                  TextField(
                    controller: bodyController,
                    decoration: const InputDecoration(labelText: 'Isi catatan'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;
                    
                    final repo = ref.read(noteRepositoryProvider);
                    await repo.addNote(
                      title: titleController.text,
                      body: bodyController.text, // Pastikan NoteRepository addNote menerima body
                    );
                    
                    ref.invalidate(notesProvider);
                    ref.invalidate(dirtyCountProvider);
                    
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Simpan'),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Catatan'),
      ),
    );
  }
}