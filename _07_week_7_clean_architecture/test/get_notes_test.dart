import 'package:flutter_test/flutter_test.dart';
import 'package:week7_clean_architecture/core/failures.dart';
import 'package:week7_clean_architecture/features/notes/domain/entities/note.dart';
import 'package:week7_clean_architecture/features/notes/domain/repositories/note_repository.dart';
import 'package:week7_clean_architecture/features/notes/domain/usecases/add_note.dart';
import 'package:week7_clean_architecture/features/notes/domain/usecases/get_notes.dart';

class FakeNoteRepository implements NoteRepository {
  FakeNoteRepository({this.items = const [], this.fail = false});

  final List<Note> items;
  final bool fail;
  Note? lastAddedNote;

  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes() async {
    if (fail) {
      return (
        notes: const <Note>[],
        failure: const LocalFailure('db locked (simulasi)'),
      );
    }
    return (notes: items, failure: null);
  }

  @override
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  }) async {
    if (fail) {
      return (
        note: null,
        failure: const LocalFailure('Gagal menyimpan catatan'),
      );
    }
    final note = Note(
      id: 999,
      title: title,
      body: body,
      updatedAt: DateTime(2026, 10, 11),
      dirty: true,
    );
    lastAddedNote = note;
    return (note: note, failure: null);
  }

  @override
  Future<({bool success, Failure? failure})> updateNote(Note note) {
    throw UnimplementedError();
  }

  @override
  Future<({bool success, Failure? failure})> deleteNote(int id) {
    throw UnimplementedError();
  }

  @override
  Future<({int count, Failure? failure})> countDirty() {
    throw UnimplementedError();
  }

  @override
  Future<({bool success, Failure? failure})> syncNotes() {
    throw UnimplementedError();
  }
}

void main() {
  group('GetNotes UseCase Unit Tests (Clean Architecture Domain)', () {
    test('GetNotes meneruskan daftar dari repository dengan sukses', () async {
      final repo = FakeNoteRepository(
        items: [
          Note(
            id: 1,
            title: 'Arsitektur Bersih',
            body: 'Prinsip dependensi mengarah ke dalam',
            updatedAt: DateTime(2026, 9, 27),
          ),
        ],
      );
      final result = await GetNotes(repo).call();

      expect(result.failure, isNull);
      expect(result.notes.length, 1);
      expect(result.notes.first.title, 'Arsitektur Bersih');
      expect(result.notes.first.id, 1);
    });

    test('GetNotes meneruskan failure tanpa melempar exception', () async {
      final repo = FakeNoteRepository(fail: true);
      final result = await GetNotes(repo).call();

      expect(result.failure, isNotNull);
      expect(result.failure, isA<LocalFailure>());
      expect(result.failure!.message, contains('db locked'));
      expect(result.notes, isEmpty);
    });
  });

  group('AddNote UseCase Unit Tests (Validation & Business Rules)', () {
    test('AddNote menolak judul kosong dengan ValidationFailure tanpa panggil repo', () async {
      final repo = FakeNoteRepository();
      final addNote = AddNote(repo);

      final result = await addNote(title: '   ', body: 'Catatan tanpa judul');

      expect(result.note, isNull);
      expect(result.failure, isA<ValidationFailure>());
      expect(result.failure!.message, 'Judul catatan tidak boleh kosong');
      expect(repo.lastAddedNote, isNull);
    });

    test(
      'AddNote memotong whitespace dan berhasil menyimpan catatan valid',
      () async {
        final repo = FakeNoteRepository();
        final addNote = AddNote(repo);

        final result = await addNote(
          title: '  Belajar SOLID  ',
          body: '  Pemisahan layer presentation, domain, data  ',
        );

        expect(result.failure, isNull);
        expect(result.note, isNotNull);
        expect(result.note!.title, 'Belajar SOLID');
        expect(result.note!.body, 'Pemisahan layer presentation, domain, data');
        expect(repo.lastAddedNote, isNotNull);
      },
    );
  });
}
