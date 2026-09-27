import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/local/note.dart';
import 'notes_page.dart';

final noteDetailProvider = FutureProvider.family<Note?, int>((ref, id) async {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.fetchNoteById(id);
});

class NoteDetailPage extends ConsumerStatefulWidget {
  final int noteId;
  const NoteDetailPage({super.key, required this.noteId});

  @override
  ConsumerState<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends ConsumerState<NoteDetailPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isInitialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _saveNote(Note oldNote) async {
    final repo = ref.read(noteRepositoryProvider);
    final updatedNote = Note(
      id: oldNote.id,
      title: _titleController.text,
      body: _bodyController.text,
      updatedAt: DateTime.now(),
      dirty: true, // Tandai kotor agar masuk antrean sync
    );

    await repo.updateNote(updatedNote);
    ref.invalidate(notesProvider);
    ref.invalidate(dirtyCountProvider);
    
    if (mounted) context.pop();
  }

  Future<void> _deleteNote() async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.deleteNote(widget.noteId);
    
    ref.invalidate(notesProvider);
    ref.invalidate(dirtyCountProvider);
    
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(noteDetailProvider(widget.noteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Catatan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              // Dialog konfirmasi hapus
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Hapus Catatan?'),
                  content: const Text('Tindakan ini tidak dapat dibatalkan.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteNote();
                      },
                      child: const Text('Hapus'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: noteAsync.when(
        data: (note) {
          if (note == null) return const Center(child: Text('Catatan tidak ditemukan'));
          
          // Memasukkan data awal ke TextField hanya sekali
          if (!_isInitialized) {
            _titleController.text = note.title;
            _bodyController.text = note.body;
            _isInitialized = true;
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  style: Theme.of(context).textTheme.headlineSmall,
                  decoration: const InputDecoration(
                    labelText: 'Judul Catatan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TextField(
                    controller: _bodyController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      labelText: 'Isi Catatan',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: noteAsync.hasValue && noteAsync.value != null
          ? FloatingActionButton.extended(
              onPressed: () => _saveNote(noteAsync.value!),
              icon: const Icon(Icons.save),
              label: const Text('Simpan'),
            )
          : null,
    );
  }
}