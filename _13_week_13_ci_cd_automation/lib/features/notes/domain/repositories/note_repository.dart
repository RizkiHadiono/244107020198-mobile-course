import '../../../../core/failures.dart';
import '../entities/note.dart';

abstract class NoteRepository {
  /// Mengambil satu halaman catatan (pagination, urut `updated_at DESC`).
  ///
  /// Week 11: parameter [limit]/[offset] ditambahkan agar UI tidak perlu
  /// memuat seluruh isi tabel sekaligus.
  Future<({List<Note> notes, Failure? failure})> fetchNotes({
    int limit = 20,
    int offset = 0,
  });

  /// Mencari catatan di seluruh isi database (bukan hanya halaman yang
  /// sudah dimuat). Implementasi wajib memakai parameter binding.
  Future<({List<Note> notes, Failure? failure})> searchNotes(String query);

  Future<({int total, Failure? failure})> countNotes();

  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  });

  Future<({bool success, Failure? failure})> updateNote(Note note);

  Future<({bool success, Failure? failure})> deleteNote(int id);

  Future<({int count, Failure? failure})> countDirty();

  Future<({bool success, Failure? failure})> syncNotes();
}
