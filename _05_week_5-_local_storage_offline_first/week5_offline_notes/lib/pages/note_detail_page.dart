import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/note.dart';
import 'notes_page.dart'; // Untuk mengakses noteRepositoryProvider

// Provider untuk mengambil 1 catatan berdasarkan ID
final noteDetailProvider = FutureProvider.family<Note?, int>((ref, id) async {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.fetchNoteById(id);
});

class NoteDetailPage extends ConsumerWidget {
  final int noteId;

  const NoteDetailPage({super.key, required this.noteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(noteDetailProvider(noteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Catatan'),
      ),
      body: noteAsync.when(
        data: (note) {
          if (note == null) return const Center(child: Text('Catatan tidak ditemukan'));
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text('Terakhir diubah: ${note.updatedAt.toString().split('.')[0]}'),
                const SizedBox(height: 16),
                Text(
                  note.body.isEmpty ? '(Tidak ada isi)' : note.body,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}