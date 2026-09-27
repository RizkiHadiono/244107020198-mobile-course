import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/local/note.dart';

class NoteTile extends StatelessWidget {
  final Note note;

  const NoteTile({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(note.title),
      subtitle: Text(note.updatedAt.toString().split('.')[0]),
      trailing: note.dirty
          ? const Icon(Icons.cloud_off, color: Colors.orange)
          : const Icon(Icons.cloud_done, color: Colors.green),
      onTap: () {
        if (note.id != null) {
          context.push('/note/${note.id}');
        }
      },
    );
  }
}