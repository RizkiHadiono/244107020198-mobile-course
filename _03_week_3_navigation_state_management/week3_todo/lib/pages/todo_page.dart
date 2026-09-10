import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/todo_provider.dart';
import '../widgets/todo_tile.dart';

class TodoPage extends ConsumerWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PERHATIKAN: Sekarang kita memantau filteredTodosProvider, bukan todoListProvider
    final todos = ref.watch(filteredTodosProvider);
    final filter = ref.watch(todoFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Tugas'),
        actions: [
          // Tombol Filter di pojok kanan atas
          PopupMenuButton<TodoFilter>(
            initialValue: filter,
            icon: const Icon(Icons.filter_list),
            // INI YANG BERUBAH: Menggunakan setFilter(value)
            onSelected: (value) => ref.read(todoFilterProvider.notifier).setFilter(value), 
            itemBuilder: (context) => const [
              PopupMenuItem(value: TodoFilter.all, child: Text('Semua')),
              PopupMenuItem(value: TodoFilter.active, child: Text('Belum Selesai')),
              PopupMenuItem(value: TodoFilter.completed, child: Text('Sudah Selesai')),
            ],
          )
        ],
      ),
      body: todos.isEmpty
          ? const Center(child: Text('Belum ada tugas'))
          : ListView.builder(
              itemCount: todos.length,
              itemBuilder: (context, index) {
                // Mencari index asli agar proses centang/hapus tidak salah target saat difilter
                final actualTodo = todos[index];
                final actualIndex = ref.read(todoListProvider).indexOf(actualTodo);

                return TodoTile(
                  todo: actualTodo,
                  index: actualIndex,
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tugas baru'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(todoListProvider.notifier).add(controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }
}