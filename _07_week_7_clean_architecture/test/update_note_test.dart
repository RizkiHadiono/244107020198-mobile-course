import 'package:flutter_test/flutter_test.dart';
import 'package:week7_clean_architecture/core/failures.dart';
import 'package:week7_clean_architecture/features/notes/domain/entities/note.dart';
import 'package:week7_clean_architecture/features/notes/domain/repositories/note_repository.dart';
import 'package:week7_clean_architecture/features/notes/domain/usecases/update_note.dart';

class FakeUpdateNoteRepository implements NoteRepository {
  bool fail = false;
  Note? lastUpdatedNote;

  @override
  Future<({bool success, Failure? failure})> updateNote(Note note) async {
    if (fail) {
      return (
        success: false,
        failure: const LocalFailure('db locked (simulasi)'),
      );
    }
    lastUpdatedNote = note;
    return (success: true, failure: null);
  }

  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes() {
    throw UnimplementedError();
  }

  @override
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  }) {
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
  group('UpdateNote UseCase Unit Tests (Validation & Business Rules)', () {
    test(
      'UpdateNote menolak judul kosong tanpa memanggil repository',
      () async {
        final repo = FakeUpdateNoteRepository();
        final useCase = UpdateNote(repo);
        final note = Note(
          id: 1,
          title: '   ',
          body: 'isi lama',
          updatedAt: DateTime(2026, 10, 24),
        );

        final result = await useCase(note);

        expect(result.success, isFalse);
        expect(result.failure, isA<ValidationFailure>());
        expect(result.failure!.message, 'Judul catatan tidak boleh kosong');
        expect(repo.lastUpdatedNote, isNull);
      },
    );

    test(
      'UpdateNote memotong whitespace judul dan isi sebelum disimpan',
      () async {
        final repo = FakeUpdateNoteRepository();
        final useCase = UpdateNote(repo);
        final note = Note(
          id: 1,
          title: '  Judul Revisi  ',
          body: '  isi revisi  ',
          updatedAt: DateTime(2026, 10, 24),
        );

        final result = await useCase(note);

        expect(result.success, isTrue);
        expect(result.failure, isNull);
        expect(repo.lastUpdatedNote, isNotNull);
        expect(repo.lastUpdatedNote!.title, 'Judul Revisi');
        expect(repo.lastUpdatedNote!.body, 'isi revisi');
      },
    );

    test(
      'UpdateNote meneruskan failure repository tanpa melempar exception',
      () async {
        final repo = FakeUpdateNoteRepository()..fail = true;
        final useCase = UpdateNote(repo);
        final note = Note(
          id: 1,
          title: 'Judul Valid',
          updatedAt: DateTime(2026, 10, 24),
        );

        final result = await useCase(note);

        expect(result.success, isFalse);
        expect(result.failure, isA<LocalFailure>());
        expect(result.failure!.message, contains('db locked'));
      },
    );
  });
}
