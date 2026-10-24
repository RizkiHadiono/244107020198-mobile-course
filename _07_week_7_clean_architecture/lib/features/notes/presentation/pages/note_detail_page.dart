import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format.dart';
import '../../domain/entities/note.dart';
import '../providers/notes_providers.dart';

class NoteDetailPage extends ConsumerStatefulWidget {
  const NoteDetailPage({super.key, required this.note});

  final Note note;

  @override
  ConsumerState<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends ConsumerState<NoteDetailPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  bool _isDirtyLocally = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _bodyController = TextEditingController(text: widget.note.body);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final updatedNote = widget.note.copyWith(
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      updatedAt: DateTime.now(),
      dirty: true,
    );

    final success = await ref
        .read(notesNotifierProvider.notifier)
        .update(updatedNote);
    if (!mounted) return;
    if (success) {
      context.pop();
    } else {
      final error =
          ref.read(notesNotifierProvider).errorMessage ?? 'Gagal memperbarui';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _deleteNote() async {
    if (widget.note.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan?'),
        content: const Text(
          'Tindakan ini akan menghapus catatan secara permanen dari basis data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref
          .read(notesNotifierProvider.notifier)
          .delete(widget.note.id!);
      if (!mounted) return;
      if (success) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime = formatDate(widget.note.updatedAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Catatan'),
        actions: [
          IconButton(
            tooltip: 'Hapus Catatan',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _deleteNote,
          ),
          if (_isDirtyLocally)
            IconButton(
              tooltip: 'Simpan Perubahan',
              icon: const Icon(Icons.check_rounded),
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(
                  'Terakhir diubah: $formattedTime',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Judul Catatan...',
                border: InputBorder.none,
              ),
              onChanged: (_) {
                if (!_isDirtyLocally) setState(() => _isDirtyLocally = true);
              },
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: _bodyController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 16, height: 1.5),
                decoration: const InputDecoration(
                  hintText: 'Mulai menulis isi catatan di sini...',
                  border: InputBorder.none,
                ),
                onChanged: (_) {
                  if (!_isDirtyLocally) setState(() => _isDirtyLocally = true);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isDirtyLocally
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FilledButton.icon(
                  onPressed: _saveChanges,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Simpan Perubahan'),
                ),
              ),
            )
          : null,
    );
  }
}
