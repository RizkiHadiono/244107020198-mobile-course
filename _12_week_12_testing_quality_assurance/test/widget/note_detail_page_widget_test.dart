import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:week12_testing_quality_assurance/core/failures.dart';
import 'package:week12_testing_quality_assurance/features/auth/presentation/providers/auth_providers.dart';
import 'package:week12_testing_quality_assurance/features/notes/domain/entities/note.dart';
import 'package:week12_testing_quality_assurance/features/notes/presentation/pages/note_detail_page.dart';
import 'package:week12_testing_quality_assurance/features/notes/presentation/providers/notes_providers.dart';

import '../support/fakes.dart';

/// Widget test halaman detail catatan: perubahan judul, penyimpanan, dan
/// penolakan judul kosong.
void main() {
  final existingNote = Note(
    id: 7,
    title: 'Judul Awal',
    body: 'Isi awal catatan',
    updatedAt: DateTime(2026, 11, 9, 8),
  );

  Widget buildSubject(FakeNoteRepository repo) {
    // Halaman detail memakai `context.pop()` dari go_router setelah simpan,
    // jadi test memakai router sungguhan dengan dua rute.
    final router = GoRouter(
      initialLocation: '/notes/7',
      routes: [
        GoRoute(
          path: '/notes',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('Daftar Catatan'))),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, _) => NoteDetailPage(note: existingNote),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        noteRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('menampilkan judul dan isi catatan yang dipilih', (tester) async {
    await tester.pumpWidget(buildSubject(FakeNoteRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Edit Catatan'), findsOneWidget);
    expect(find.text('Judul Awal'), findsOneWidget);
    expect(find.text('Isi awal catatan'), findsOneWidget);
    // Tombol simpan belum muncul karena belum ada perubahan.
    expect(find.byKey(const Key('noteDetailSaveButton')), findsNothing);
  });

  testWidgets('menyimpan perubahan judul lalu kembali ke daftar', (
    tester,
  ) async {
    final repo = FakeNoteRepository(notes: [existingNote]);

    await tester.pumpWidget(buildSubject(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('noteDetailTitleField')),
      'Judul Setelah Revisi',
    );
    await tester.pump();

    // Tombol simpan muncul setelah ada perubahan.
    expect(find.byKey(const Key('noteDetailSaveButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('noteDetailSaveButton')));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(repo.notes.single.title, 'Judul Setelah Revisi');
    expect(find.text('Daftar Catatan'), findsOneWidget);
  });

  testWidgets('judul kosong ditolak dan tidak memanggil repository', (
    tester,
  ) async {
    final repo = FakeNoteRepository(notes: [existingNote]);

    await tester.pumpWidget(buildSubject(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('noteDetailTitleField')),
      '   ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('noteDetailSaveButton')));
    await tester.pumpAndSettle();

    expect(find.text('Judul catatan tidak boleh kosong'), findsOneWidget);
    expect(repo.updateCalls, 0);
    expect(find.text('Edit Catatan'), findsOneWidget);
  });

  testWidgets('kegagalan menyimpan menampilkan SnackBar dan tetap di halaman', (
    tester,
  ) async {
    final repo = FakeNoteRepository(
      notes: [existingNote],
      updateFailure: const LocalFailure('Gagal memperbarui catatan'),
    );

    await tester.pumpWidget(buildSubject(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('noteDetailTitleField')),
      'Judul Gagal',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('noteDetailSaveButton')));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(find.text('Gagal memperbarui catatan'), findsOneWidget);
    expect(find.text('Edit Catatan'), findsOneWidget);
  });
}
