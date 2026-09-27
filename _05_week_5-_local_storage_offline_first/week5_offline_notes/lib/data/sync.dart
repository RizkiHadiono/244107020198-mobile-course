import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import 'post.dart';
import 'local/db.dart';
import 'repositories/note_repository.dart';

class SyncService {
  final Dio _dio;
  final Future<Database> Function() _openDb;

  SyncService(this._dio, {Future<Database> Function()? openDb})
      : _openDb = openDb ?? openNotesDb;

  Future<List<Post>> loadPostsCacheFirst(bool isOffline) async {
    final db = await _openDb();

    final rows = await db.query('cached_posts', orderBy: 'id ASC');
    final cached = rows.map((row) {
      final map = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      return Post.fromJson(map);
    }).toList();

    _refreshPostsInBackground(isOffline, db);

    return cached;
  }

  Future<void> _refreshPostsInBackground(bool isOffline, Database db) async {
    try {
      if (isOffline) throw Exception('Simulasi Offline Aktif');

      final response = await _dio.get<List>('https://jsonplaceholder.typicode.com/posts');
      final data = response.data ?? [];

      await db.transaction((txn) async {
        await txn.delete('cached_posts'); 
        for (final item in data.whereType<Map<String, dynamic>>()) {
          final post = Post.fromJson(item);
          await txn.insert('cached_posts', {
            'id': post.id,
            'payload': jsonEncode(post.toJson()),
            'cached_at': DateTime.now().toIso8601String(),
          });
        }
      });
    } catch (e) {
      // Abaikan error saat offline
    }
  }

  Future<int> syncNotes(NoteRepository repo, bool isOffline) async {
    if (isOffline) throw Exception('Simulasi offline aktif, sinkronisasi dibatalkan.');

    final dirtyCount = await repo.countDirty();
    if (dirtyCount == 0) return 0;

    await Future.delayed(const Duration(seconds: 1)); // Simulasi API delay
    await repo.markAllSynced();
    return dirtyCount;
  }
}