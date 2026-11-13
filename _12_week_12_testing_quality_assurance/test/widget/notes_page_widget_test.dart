import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week12_testing_quality_assurance/core/failures.dart';
import 'package:week12_testing_quality_assurance/features/auth/domain/entities/user.dart';
import 'package:week12_testing_quality_assurance/features/auth/presentation/providers/auth_providers.dart';
import 'package:week12_testing_quality_assurance/features/notes/domain/entities/note.dart';
import 'package:week12_testing_quality_assurance/features/notes/presentation/pages/notes_page.dart';
import 'package:week12_testing_quality_assurance/features/notes/presentation/providers/notes_providers.dart';

import '../support/fakes.dart';

/// Widget test untuk halaman daftar catatan.
///
/// Seluruh dependensi (repository catatan dan repository autentikasi) diganti
/// fake, sehingga test tidak memerlukan SQLite, SharedPreferences, maupun
/// jaringan. Yang diuji adalah perilaku yang dilihat pengguna.
void main() {
  Note note({
    required int id,
    required String title,
    String body = 'Isi catatan',
    int day = 1,
  }) => Note(
    id: id,
    title: title,
    body: body,
    updatedAt: DateTime(2026, 11, day, 10),
  );

  Widget buildSubject({
    required FakeNoteRepository repo,
    User? user = const User(
      id: 'usr_test',
      email: 'mhs@polinema.ac.id',
      name: 'Mahasiswa',
      token: 'token-test',
    ),
  }) {
    return ProviderScope(
      overrides: [
        noteRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(currentUser: user),
        ),
      ],
      child: const MaterialApp(home: NotesPage()),
    );
  }

  testWidgets('menampilkan indikator loading lalu daftar catatan', (
    tester,
  ) async {
    final repo = FakeNoteRepository(
      notes: [
        note(id: 1, title: 'Belanja Bulanan', day: 3),
        note(id: 2, title: 'Belajar Widget Test', day: 2),
      ],
      latency: const Duration(milliseconds: 100),
    );

    await tester.pumpWidget(buildSubject(repo: repo));

    // Frame pertama: data belum siap, indikator loading tampil.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    // Setelah data siap: daftar tampil, indikator hilang.
    expect(find.text('Belanja Bulanan'), findsOneWidget);
    expect(find.text('Belajar Widget Test'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('addNoteFab')), findsOneWidget);
  });

  testWidgets('menampilkan empty state saat belum ada catatan', (tester) async {
    await tester.pumpWidget(buildSubject(repo: FakeNoteRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada catatan'), findsOneWidget);
    expect(find.text('Tekan tombol di bawah untuk menambahkan catatan pertama.'),
        findsOneWidget);
  });

  testWidgets('menampilkan pesan error dan pulih setelah Coba Lagi', (
    tester,
  ) async {
    final repo = FakeNoteRepository(
      notes: [note(id: 1, title: 'Catatan Setelah Pulih')],
      fetchFailure: const LocalFailure('Gagal membaca database lokal'),
    );

    await tester.pumpWidget(buildSubject(repo: repo));
    await tester.pumpAndSettle();

    // Kondisi gagal: pesan error + tombol retry, daftar tidak tampil.
    expect(find.text('Gagal membaca database lokal'), findsOneWidget);
    expect(find.byKey(const Key('notesErrorRetry')), findsOneWidget);
    expect(find.text('Catatan Setelah Pulih'), findsNothing);

    // Arrange ulang: repository kini sehat.
    repo.fetchFailure = null;
    await tester.tap(find.byKey(const Key('notesErrorRetry')));
    await tester.pumpAndSettle();

    expect(find.text('Gagal membaca database lokal'), findsNothing);
    expect(find.text('Catatan Setelah Pulih'), findsOneWidget);
  });

  testWidgets('pengguna dapat menambahkan catatan baru', (tester) async {
    final repo = FakeNoteRepository(notes: [note(id: 1, title: 'Catatan Lama')]);

    await tester.pumpWidget(buildSubject(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addNoteFab')));
    await tester.pumpAndSettle();

    expect(find.text('Buat Catatan Baru'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('noteTitleField')),
      'Rangkuman Testing',
    );
    await tester.enterText(
      find.byKey(const Key('noteBodyField')),
      'Unit, widget, dan integrasi',
    );
    await tester.tap(find.byKey(const Key('noteSaveButton')));
    await tester.pumpAndSettle();

    // Dialog tertutup, catatan baru muncul di daftar, repository dipanggil.
    expect(find.text('Buat Catatan Baru'), findsNothing);
    expect(find.text('Rangkuman Testing'), findsOneWidget);
    expect(repo.addCalls, 1);
    expect(repo.notes.any((n) => n.title == 'Rangkuman Testing'), isTrue);
  });

  testWidgets('judul kosong ditolak tanpa memanggil repository', (tester) async {
    final repo = FakeNoteRepository(notes: [note(id: 1, title: 'Catatan Lama')]);

    await tester.pumpWidget(buildSubject(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addNoteFab')));
    await tester.pumpAndSettle();

    // Hanya spasi: tetap dianggap kosong.
    await tester.enterText(find.byKey(const Key('noteTitleField')), '     ');
    await tester.tap(find.byKey(const Key('noteSaveButton')));
    await tester.pumpAndSettle();

    expect(find.text('Judul catatan tidak boleh kosong'), findsOneWidget);
    expect(find.text('Buat Catatan Baru'), findsOneWidget);
    expect(repo.addCalls, 0);
  });

  testWidgets('kegagalan menyimpan menampilkan SnackBar dan dialog tetap terbuka', (
    tester,
  ) async {
    final repo = FakeNoteRepository(addFailure: const LocalFailure('Disk penuh'));

    await tester.pumpWidget(buildSubject(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('addNoteFab')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('noteTitleField')),
      'Catatan Gagal',
    );
    await tester.tap(find.byKey(const Key('noteSaveButton')));
    await tester.pumpAndSettle();

    expect(repo.addCalls, 1);
    expect(find.widgetWithText(SnackBar, 'Disk penuh'), findsOneWidget);
    expect(find.text('Catatan Gagal'), findsOneWidget);
  });

  testWidgets('menggeser kartu ke kiri menghapus catatan', (tester) async {
    final repo = FakeNoteRepository(
      notes: [
        note(id: 1, title: 'Catatan Akan Dihapus', day: 3),
        note(id: 2, title: 'Catatan Tetap Ada', day: 2),
      ],
    );

    await tester.pumpWidget(buildSubject(repo: repo));
    await tester.pumpAndSettle();

    await tester.drag(
      find.text('Catatan Akan Dihapus'),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, 1);
    expect(repo.notes.any((n) => n.title == 'Catatan Akan Dihapus'), isFalse);
    expect(find.text('Catatan Akan Dihapus'), findsNothing);
    expect(find.text('Catatan Tetap Ada'), findsOneWidget);
  });
}
