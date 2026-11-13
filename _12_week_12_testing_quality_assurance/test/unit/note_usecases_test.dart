import 'package:flutter_test/flutter_test.dart';
import 'package:week12_testing_quality_assurance/core/failures.dart';
import 'package:week12_testing_quality_assurance/core/validation/note_validator.dart';
import 'package:week12_testing_quality_assurance/features/notes/domain/entities/note.dart';
import 'package:week12_testing_quality_assurance/features/notes/domain/usecases/add_note.dart';
import 'package:week12_testing_quality_assurance/features/notes/domain/usecases/get_notes.dart';
import 'package:week12_testing_quality_assurance/features/notes/domain/usecases/update_note.dart';

import '../support/fakes.dart';

/// Unit test use case catatan dengan **fake repository**.
///
/// Tidak ada SQLite, tidak ada plugin platform, tidak ada jaringan. Setiap
/// skenario mengendalikan repository sepenuhnya sehingga hasilnya deterministik.
void main() {
  Note sampleNote({int id = 1, String title = 'Catatan Awal'}) => Note(
    id: id,
    title: title,
    body: 'Isi catatan',
    updatedAt: DateTime(2026, 11, 10, 9),
  );

  group('GetNotes dengan fake repository', () {
    test('meneruskan daftar catatan dari repository apa adanya', () async {
      final repo = FakeNoteRepository(notes: [sampleNote()]);

      final result = await GetNotes(repo).call();

      expect(result.failure, isNull);
      expect(result.notes, hasLength(1));
      expect(result.notes.single.title, 'Catatan Awal');
    });

    test('meneruskan parameter limit dan offset ke repository', () async {
      final repo = FakeNoteRepository(
        notes: List.generate(30, (i) => sampleNote(id: i + 1)),
      );

      final first = await GetNotes(repo).call(limit: 20, offset: 0);
      final second = await GetNotes(repo).call(limit: 20, offset: 20);

      expect(first.notes, hasLength(20));
      expect(second.notes, hasLength(10));
      expect(repo.lastLimit, 20);
      expect(repo.lastOffset, 20);
    });

    test('kegagalan repository dikembalikan sebagai failure, bukan daftar kosong '
        'diam-diam', () async {
      final repo = FakeNoteRepository(
        fetchFailure: const LocalFailure('database terkunci'),
      );

      final result = await GetNotes(repo).call();

      expect(result.failure, isNotNull);
      expect(result.failure, isA<LocalFailure>());
      expect(result.failure!.message, 'database terkunci');
      expect(result.notes, isEmpty);
    });
  });

  group('AddNote dengan fake repository', () {
    test('menyimpan judul dan isi yang sudah di-trim', () async {
      final repo = FakeNoteRepository();
      final addNote = AddNote(repo);

      final result = await addNote(
        title: '  Belajar Testing  ',
        body: '  Arrange, Act, Assert  ',
      );

      expect(result.failure, isNull);
      expect(result.note, isNotNull);
      expect(repo.addCalls, 1);
      expect(repo.notes.single.title, 'Belajar Testing');
      expect(repo.notes.single.body, 'Arrange, Act, Assert');
    });

    test('menolak judul kosong tanpa memanggil repository', () async {
      final repo = FakeNoteRepository();

      final result = await AddNote(repo).call(title: '   ');

      expect(result.note, isNull);
      expect(result.failure, isA<ValidationFailure>());
      expect(result.failure!.message, 'Judul catatan tidak boleh kosong');
      expect(repo.addCalls, 0);
    });

    test('menolak judul melebihi batas panjang tanpa memanggil repository', () async {
      final repo = FakeNoteRepository();
      final tooLong = List.filled(kMaxNoteTitleLength + 1, 'x').join();

      final result = await AddNote(repo).call(title: tooLong);

      expect(result.failure, isA<ValidationFailure>());
      expect(repo.addCalls, 0);
    });

    test('kegagalan penyimpanan diteruskan ke pemanggil', () async {
      final repo = FakeNoteRepository(
        addFailure: const LocalFailure('disk penuh'),
      );

      final result = await AddNote(repo).call(title: 'Catatan Baru');

      expect(result.note, isNull);
      expect(result.failure!.message, 'disk penuh');
      expect(repo.notes, isEmpty);
    });
  });

  group('UpdateNote dengan fake repository', () {
    test('memperbarui catatan yang ada', () async {
      final repo = FakeNoteRepository(notes: [sampleNote()]);
      final updated = sampleNote().copyWith(title: 'Judul Baru');

      final result = await UpdateNote(repo).call(updated);

      expect(result.success, isTrue);
      expect(repo.notes.single.title, 'Judul Baru');
    });

    test('menolak judul kosong tanpa memanggil repository', () async {
      final repo = FakeNoteRepository(notes: [sampleNote()]);

      final result = await UpdateNote(repo).call(
        sampleNote().copyWith(title: '   '),
      );

      expect(result.success, isFalse);
      expect(result.failure, isA<ValidationFailure>());
      expect(repo.updateCalls, 0);
    });

    test('mengembalikan failure saat catatan tidak ditemukan', () async {
      final repo = FakeNoteRepository();

      final result = await UpdateNote(repo).call(sampleNote(id: 404));

      expect(result.success, isFalse);
      expect(result.failure, isA<LocalFailure>());
    });
  });
}
