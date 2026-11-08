import '../core/failures.dart';
import '../features/notes/domain/entities/note.dart';
import '../features/notes/domain/repositories/note_repository.dart';

/// Repository in-memory untuk harness profiling.
///
/// Hanya **sumber data** yang diganti; widget, provider, dan use case yang
/// diukur tetap kode produksi. Dengan 300 catatan, perilaku daftar panjang
/// dapat direproduksi tanpa bergantung pada isi database perangkat.
class InMemoryNoteRepository implements NoteRepository {
  InMemoryNoteRepository({int count = 300}) : _notes = _seed(count);

  final List<Note> _notes;

  static List<Note> _seed(int count) {
    final base = DateTime(2026, 11, 1, 8);
    return List<Note>.generate(count, (i) {
      final id = i + 1;
      return Note(
        id: id,
        title: 'Catatan Praktikum #$id',
        body:
            'Ringkasan materi pertemuan ke-$id: arsitektur, profiling, dan '
            'optimasi performa aplikasi mobile.',
        updatedAt: base.subtract(Duration(hours: i * 5)),
        dirty: i % 7 == 0,
      );
    });
  }

  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes({
    int limit = 20,
    int offset = 0,
  }) async {
    final sorted = [..._notes]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final page = sorted.skip(offset).take(limit).toList(growable: false);
    return (notes: page, failure: null);
  }

  @override
  Future<({List<Note> notes, Failure? failure})> searchNotes(
    String query,
  ) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return (notes: const <Note>[], failure: null);
    final matches = _notes
        .where((n) => n.title.toLowerCase().contains(q))
        .toList(growable: false);
    return (notes: matches, failure: null);
  }

  @override
  Future<({int total, Failure? failure})> countNotes() async {
    return (total: _notes.length, failure: null);
  }

  @override
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  }) async {
    final note = Note(
      id: _notes.length + 1,
      title: title,
      body: body,
      updatedAt: DateTime.now(),
      dirty: true,
    );
    _notes.add(note);
    return (note: note, failure: null);
  }

  @override
  Future<({bool success, Failure? failure})> updateNote(Note note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index == -1) {
      return (success: false, failure: const LocalFailure('Tidak ditemukan'));
    }
    _notes[index] = note;
    return (success: true, failure: null);
  }

  @override
  Future<({bool success, Failure? failure})> deleteNote(int id) async {
    _notes.removeWhere((n) => n.id == id);
    return (success: true, failure: null);
  }

  @override
  Future<({int count, Failure? failure})> countDirty() async {
    return (count: _notes.where((n) => n.dirty).length, failure: null);
  }

  @override
  Future<({bool success, Failure? failure})> syncNotes() async {
    for (var i = 0; i < _notes.length; i++) {
      _notes[i] = _notes[i].copyWith(dirty: false);
    }
    return (success: true, failure: null);
  }
}
