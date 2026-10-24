import 'package:sqflite/sqflite.dart';

import '../../../../core/failures.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../models/note_model.dart';

class NoteRepositoryImpl implements NoteRepository {
  NoteRepositoryImpl({required this.openDb});

  final Future<Database> Function() openDb;

  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes() async {
    try {
      final db = await openDb();
      final rows = await db.query('notes', orderBy: 'updated_at DESC');
      final notes = rows.map((r) => NoteModel.fromMap(r).toEntity()).toList();
      return (notes: notes, failure: null);
    } catch (e) {
      return (
        notes: const <Note>[],
        failure: LocalFailure('Gagal membaca catatan dari database lokal: $e'),
      );
    }
  }

  @override
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  }) async {
    try {
      final db = await openDb();
      final now = DateTime.now();
      final model = NoteModel(
        title: title,
        body: body,
        updatedAt: now,
        dirty: true,
      );
      final id = await db.insert('notes', model.toMap());
      return (
        note: Note(
          id: id,
          title: title,
          body: body,
          updatedAt: now,
          dirty: true,
        ),
        failure: null,
      );
    } catch (e) {
      return (note: null, failure: LocalFailure('Gagal menyimpan catatan: $e'));
    }
  }

  @override
  Future<({bool success, Failure? failure})> updateNote(Note note) async {
    try {
      final db = await openDb();
      final now = DateTime.now();
      final model = NoteModel(
        id: note.id,
        title: note.title,
        body: note.body,
        updatedAt: now,
        dirty: true,
      );
      final rowsUpdated = await db.update(
        'notes',
        model.toMap(),
        where: 'id = ?',
        whereArgs: [note.id],
      );
      if (rowsUpdated == 0) {
        return (
          success: false,
          failure: const LocalFailure(
            'Catatan tidak ditemukan untuk diperbarui',
          ),
        );
      }
      return (success: true, failure: null);
    } catch (e) {
      return (
        success: false,
        failure: LocalFailure('Gagal memperbarui catatan: $e'),
      );
    }
  }

  @override
  Future<({bool success, Failure? failure})> deleteNote(int id) async {
    try {
      final db = await openDb();
      final rowsDeleted = await db.delete(
        'notes',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rowsDeleted == 0) {
        return (
          success: false,
          failure: const LocalFailure('Catatan tidak ditemukan untuk dihapus'),
        );
      }
      return (success: true, failure: null);
    } catch (e) {
      return (
        success: false,
        failure: LocalFailure('Gagal menghapus catatan: $e'),
      );
    }
  }

  @override
  Future<({int count, Failure? failure})> countDirty() async {
    try {
      final db = await openDb();
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM notes WHERE dirty = 1',
      );
      final count = (rows.first['c'] as num?)?.toInt() ?? 0;
      return (count: count, failure: null);
    } catch (e) {
      return (
        count: 0,
        failure: LocalFailure('Gagal menghitung catatan antrean: $e'),
      );
    }
  }

  @override
  Future<({bool success, Failure? failure})> syncNotes() async {
    try {
      final db = await openDb();
      // Simulasi proses pengiriman catatan dirty ke REST API/server
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await db.update('notes', {'dirty': 0}, where: 'dirty = 1');
      return (success: true, failure: null);
    } catch (e) {
      return (
        success: false,
        failure: NetworkFailure('Gagal sinkronisasi catatan ke cloud: $e'),
      );
    }
  }
}
