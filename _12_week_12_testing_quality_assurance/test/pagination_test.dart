import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week12_testing_quality_assurance/features/notes/presentation/providers/notes_providers.dart';
import 'package:week12_testing_quality_assurance/perf/in_memory_note_repository.dart';

/// ProviderContainer dengan repository in-memory berisi [count] catatan.
ProviderContainer _container(int count) {
  final container = ProviderContainer(
    overrides: [
      noteRepositoryProvider.overrideWithValue(
        InMemoryNoteRepository(count: count),
      ),
      dirtyNotesCountProvider.overrideWith((ref) async => 0),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('Pagination daftar catatan', () {
    test('halaman pertama hanya memuat 20 catatan, bukan seluruh tabel', () async {
      final container = _container(45);
      final notifier = container.read(notesNotifierProvider.notifier);

      await notifier.loadNotes();
      final state = container.read(notesNotifierProvider);

      expect(state.notes.length, kNotesPageSize);
      expect(state.total, 45);
      expect(state.hasMore, isTrue);
    });

    test('loadMore menambahkan halaman berikutnya tanpa duplikasi', () async {
      final container = _container(45);
      final notifier = container.read(notesNotifierProvider.notifier);

      await notifier.loadNotes();
      await notifier.loadMore();
      expect(container.read(notesNotifierProvider).notes.length, 40);

      await notifier.loadMore();
      final state = container.read(notesNotifierProvider);
      expect(state.notes.length, 45);
      expect(state.hasMore, isFalse);

      final ids = state.notes.map((n) => n.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'tidak boleh duplikat');
    });

    test('loadMore tidak berjalan lagi setelah hasMore = false', () async {
      final container = _container(5);
      final notifier = container.read(notesNotifierProvider.notifier);

      await notifier.loadNotes();
      expect(container.read(notesNotifierProvider).hasMore, isFalse);

      await notifier.loadMore();
      expect(container.read(notesNotifierProvider).notes.length, 5);
    });
  });

  group('Isolasi rebuild dengan select', () {
    test('mengubah query pencarian tidak memicu ulang provider total', () async {
      final container = _container(30);
      final notifier = container.read(notesNotifierProvider.notifier);
      await notifier.loadNotes();

      var totalEmits = 0;
      container.listen<int>(notesTotalProvider, (_, _) => totalEmits++);

      notifier.setSearchQuery('prak');
      notifier.setSearchQuery('praktikum');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(totalEmits, 0, reason: 'total tidak berubah saat mengetik');
    });

    test('pencarian mencari ke seluruh database, bukan hanya halaman aktif', () async {
      final container = _container(300);
      final notifier = container.read(notesNotifierProvider.notifier);
      await notifier.loadNotes();
      expect(container.read(notesNotifierProvider).notes.length, 20);

      // Catatan #250 tidak ada di halaman pertama.
      notifier.setSearchQuery('Praktikum #250');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      final results = container.read(notesNotifierProvider).searchResults;
      expect(results.length, 1);
      expect(results.first.id, 250);
    });
  });
}
