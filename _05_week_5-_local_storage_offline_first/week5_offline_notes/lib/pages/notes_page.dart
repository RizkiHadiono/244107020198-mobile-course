import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../data/repositories/note_repository.dart';
import '../data/local/note.dart';
import '../data/sync.dart';

// 1. NotifierProvider untuk Mode Offline (Cara Modern Riverpod)
class ForceOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle(bool value) {
    state = value;
  }
}

final forceOfflineProvider = NotifierProvider<ForceOfflineNotifier, bool>(ForceOfflineNotifier.new);

// 2. Provider Database dan Data
final noteRepositoryProvider = Provider((ref) => NoteRepository());

final notesProvider = FutureProvider<List<Note>>((ref) async {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.fetchNotes();
});

final dirtyCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.countDirty();
});

// 3. UI Utama
class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    final dirtyCountAsync = ref.watch(dirtyCountProvider);
    final isOffline = ref.watch(forceOfflineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Notes'),
        actions: [
          // Badge Antrean Sync
          dirtyCountAsync.when(
            data: (count) {
              if (count == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: Badge(
                    label: Text(count.toString()),
                    child: const Icon(Icons.sync_problem),
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Force Offline Mode'),
            subtitle: const Text('Simulasi matikan internet'),
            value: isOffline,
            onChanged: (value) {
              ref.read(forceOfflineProvider.notifier).toggle(value);
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FilledButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text('Sync Notes'),
              onPressed: () async {
                try {
                  final syncService = SyncService(Dio());
                  final repo = ref.read(noteRepositoryProvider);
                  
                  await syncService.syncNotes(repo, isOffline);
                  
                  ref.invalidate(dirtyCountProvider); 
                  ref.invalidate(notesProvider);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sinkronisasi berhasil!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
            ),
          ),
          const Divider(),
          // Daftar Catatan
          Expanded(
            child: notesAsync.when(
              data: (notes) {
                if (notes.isEmpty) {
                  return const Center(child: Text('Belum ada catatan.'));
                }
                return ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return ListTile(
                      title: Text(note.title),
                      subtitle: Text(note.updatedAt.toString().split('.')[0]),
                      trailing: note.dirty 
                          ? const Icon(Icons.cloud_off, color: Colors.orange)
                          : const Icon(Icons.cloud_done, color: Colors.green),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final repo = ref.read(noteRepositoryProvider);
          await repo.addNote(title: 'Catatan Baru ${DateTime.now().second}');
          
          ref.invalidate(notesProvider);
          ref.invalidate(dirtyCountProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}