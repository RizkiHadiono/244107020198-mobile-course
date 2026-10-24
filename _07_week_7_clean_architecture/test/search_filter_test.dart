import 'package:flutter_test/flutter_test.dart';
import 'package:week7_clean_architecture/features/notes/domain/entities/note.dart';
import 'package:week7_clean_architecture/features/notes/domain/usecases/search_notes.dart';

void main() {
  final sample = [
    Note(id: 1, title: 'Belanja Bulanan', updatedAt: DateTime(2026, 10, 1)),
    Note(id: 2, title: 'belajar riverpod', updatedAt: DateTime(2026, 10, 2)),
    Note(id: 3, title: 'Rapat Proyek', updatedAt: DateTime(2026, 10, 3)),
    Note(
      id: 4,
      title: 'Belajar Clean Architecture',
      updatedAt: DateTime(2026, 10, 4),
    ),
  ];

  group('SearchNotes UseCase (domain, murni Dart)', () {
    test('query kosong mengembalikan semua catatan', () {
      const search = SearchNotes();
      final result = search.call(sample, '   ');
      expect(result, hasLength(4));
    });

    test('filter abaikan huruf besar/kecil (case-insensitive)', () {
      const search = SearchNotes();
      final result = search.call(sample, 'belajar');
      expect(result, hasLength(2));
      expect(result.map((n) => n.id), containsAll(<int>[2, 4]));
    });

    test('query cocok sebagian kata tetap mengembalikan hasil', () {
      const search = SearchNotes();
      final result = search.call(sample, 'rapat');
      expect(result, hasLength(1));
      expect(result.first.title, 'Rapat Proyek');
    });

    test('query tak cocok mengembalikan list kosong (empty state)', () {
      const search = SearchNotes();
      final result = search.call(sample, 'zzz-tak-ada');
      expect(result, isEmpty);
    });
  });
}
