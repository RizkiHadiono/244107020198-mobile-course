import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/todo_provider.dart';
import '../widgets/todo_tile.dart';

class TodoPage extends ConsumerWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(filteredTodosProvider);
    final currentFilter = ref.watch(todoFilterProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Workspace Tugas', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          PopupMenuButton<TodoCategoryFilter>(
            initialValue: currentFilter,
            icon: const Icon(Icons.tune, color: Colors.white),
            onSelected: (val) => ref.read(todoFilterProvider.notifier).setFilter(val),
            itemBuilder: (context) => const [
              PopupMenuItem(value: TodoCategoryFilter.all, child: Text('Semua Kategori')),
              PopupMenuItem(value: TodoCategoryFilter.desain, child: Text('Desain')),
              PopupMenuItem(value: TodoCategoryFilter.koding, child: Text('Koding')),
              PopupMenuItem(value: TodoCategoryFilter.lainnya, child: Text('Lainnya')),
            ],
          )
        ],
      ),
      body: todos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 70, color: Colors.deepPurple.shade200),
                  const SizedBox(height: 12),
                  const Text('Belum ada tugas di kategori ini', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: todos.length,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemBuilder: (context, index) => TodoCardTile(todo: todos[index]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepPurple,
        onPressed: () => _showAddModal(context, ref),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tugas Baru', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showAddModal(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    String selectedCategory = 'Koding';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tambah Tugas Baru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Judul Tugas',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.deepPurple, width: 2)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: ['Koding', 'Desain', 'Lainnya'].map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (val) {
                if (val != null) selectedCategory = val;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (titleController.text.trim().isNotEmpty) {
                    ref.read(todoListProvider.notifier).add(titleController.text.trim(), selectedCategory);
                  }
                  Navigator.pop(context);
                },
                child: const Text('Simpan Tugas', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}