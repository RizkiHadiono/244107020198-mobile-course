import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:week12_testing_quality_assurance/core/failures.dart';
import 'package:week12_testing_quality_assurance/features/notes/data/repositories/note_repository_impl.dart';
import 'package:week12_testing_quality_assurance/features/notes/domain/entities/note.dart';

/// Unit test untuk implementasi repository SQL yang sebenarnya.
///
/// `sqflite` tidak dapat berjalan di Dart VM biasa, sehingga pengujian memakai
/// `sqflite_common_ffi` dengan database di memori. Yang diuji bukan tiruan:
/// query, klausa `WHERE`, `ORDER BY`, `LIMIT/OFFSET`, dan penanganan error
/// benar benar dieksekusi oleh mesin SQLite.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late NoteRepositoryImpl repository;

  Future<Database> openMemoryDb() => databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            body TEXT NOT NULL DEFAULT '',
            updated_at TEXT NOT NULL,
            dirty INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    ),
  );

  setUp(() async {
    db = await openMemoryDb();
    repository = NoteRepositoryImpl(openDb: () async => db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seed(int count) async {
    for (var i = 1; i <= count; i++) {
      await repository.addNote(
        title: 'Catatan $i',
        body: 'Isi catatan $i',
      );
      // Memberi jeda kecil agar urutan `updated_at` unik dan deterministik.
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  group('NoteRepositoryImpl di SQLite sungguhan', () {
    test('addNote menyimpan baris dan mengembalikan id', () async {
      final result = await repository.addNote(
        title: 'Catatan Pertama',
        body: 'Isi',
      );

      expect(result.failure, isNull);
      expect(result.note!.id, isNotNull);
      expect(result.note!.dirty, isTrue);

      final count = await repository.countNotes();
      expect(count.total, 1);
    });

    test('fetchNotes menghormati limit dan offset (pagination)', () async {
      await seed(25);

      final page1 = await repository.fetchNotes(limit: 20, offset: 0);
      final page2 = await repository.fetchNotes(limit: 20, offset: 20);

      expect(page1.notes, hasLength(20));
      expect(page2.notes, hasLength(5));

      final idsPage1 = page1.notes.map((n) => n.id).toSet();
      final idsPage2 = page2.notes.map((n) => n.id).toSet();
      expect(idsPage1.intersection(idsPage2), isEmpty);
    });

    test('fetchNotes mengurutkan dari yang paling baru diubah', () async {
      await seed(3);

      final result = await repository.fetchNotes();

      expect(result.notes.first.title, 'Catatan 3');
      expect(result.notes.last.title, 'Catatan 1');
    });

    test('searchNotes mencari sebagian judul tanpa peduli besar kecil huruf', () async {
      await repository.addNote(title: 'Belajar Flutter');
      await repository.addNote(title: 'Belajar SQLite');
      await repository.addNote(title: 'Liburan');

      final result = await repository.searchNotes('belajar');

      expect(result.notes, hasLength(2));
      expect(result.notes.every((n) => n.title.contains('Belajar')), isTrue);
    });

    test('searchNotes dengan query kosong mengembalikan daftar kosong', () async {
      await seed(2);

      final result = await repository.searchNotes('   ');

      expect(result.notes, isEmpty);
      expect(result.failure, isNull);
    });

    test('searchNotes memperlakukan wildcard LIKE sebagai teks biasa', () async {
      await repository.addNote(title: 'Catatan Biasa');
      await repository.addNote(title: 'Catatan Lain');
      await repository.addNote(title: 'Diskon 50% Spesial');

      // Tanpa escape, '%' akan cocok dengan semua baris. Dengan escape,
      // hanya judul yang benar-benar memuat karakter '%' yang dikembalikan.
      final percent = await repository.searchNotes('%');
      expect(percent.notes, hasLength(1));
      expect(percent.notes.single.title, 'Diskon 50% Spesial');

      // '_' juga wildcard satu karakter di LIKE.
      final underscore = await repository.searchNotes('_');
      expect(underscore.notes, isEmpty);
    });

    test('updateNote mengubah baris yang ada dan menandainya dirty', () async {
      final created = await repository.addNote(title: 'Judul Lama');
      final id = created.note!.id!;

      final result = await repository.updateNote(
        Note(
          id: id,
          title: 'Judul Baru',
          body: 'Isi baru',
          updatedAt: DateTime(2026, 11, 12, 10),
        ),
      );

      expect(result.success, isTrue);

      final fetched = await repository.fetchNotes();
      expect(fetched.notes.single.title, 'Judul Baru');
      expect(fetched.notes.single.dirty, isTrue);
    });

    test('updateNote mengembalikan failure saat id tidak ada', () async {
      final result = await repository.updateNote(
        Note(
          id: 999,
          title: 'Tidak Ada',
          updatedAt: DateTime(2026, 11, 12),
        ),
      );

      expect(result.success, isFalse);
      expect(result.failure, isA<LocalFailure>());
      expect(result.failure!.message, contains('tidak ditemukan'));
    });

    test('deleteNote menghapus baris yang dipilih saja', () async {
      final a = await repository.addNote(title: 'Hapus Saya');
      await repository.addNote(title: 'Pertahankan Saya');

      final result = await repository.deleteNote(a.note!.id!);

      expect(result.success, isTrue);
      final remaining = await repository.fetchNotes();
      expect(remaining.notes.single.title, 'Pertahankan Saya');
    });

    test('deleteNote mengembalikan failure saat id tidak ada', () async {
      final result = await repository.deleteNote(4242);

      expect(result.success, isFalse);
      expect(result.failure, isA<LocalFailure>());
    });

    test('countDirty menghitung hanya catatan yang belum tersinkron', () async {
      await seed(4);

      final result = await repository.countDirty();

      expect(result.failure, isNull);
      expect(result.count, 4);
    });

    test('syncNotes membersihkan seluruh antrean dirty', () async {
      await seed(3);

      final sync = await repository.syncNotes();
      expect(sync.success, isTrue);

      final dirty = await repository.countDirty();
      expect(dirty.count, 0);
    });

    test('kegagalan membuka database dikembalikan sebagai failure', () async {
      final broken = NoteRepositoryImpl(
        openDb: () async => throw Exception('db tidak dapat dibuka'),
      );

      final fetched = await broken.fetchNotes();
      final counted = await broken.countNotes();

      expect(fetched.failure, isA<LocalFailure>());
      expect(fetched.notes, isEmpty);
      expect(counted.failure, isA<LocalFailure>());
      expect(counted.total, 0);
    });
  });
}
