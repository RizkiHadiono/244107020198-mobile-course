import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:week7_clean_architecture/features/auth/domain/entities/user.dart';
import 'package:week7_clean_architecture/features/auth/presentation/providers/auth_providers.dart';
import 'package:week7_clean_architecture/features/notes/domain/entities/note.dart';
import 'package:week7_clean_architecture/features/notes/presentation/pages/notes_page.dart';
import 'package:week7_clean_architecture/features/notes/presentation/providers/notes_providers.dart';

/// Notifier palsu: langsung menyajikan 3 catatan tanpa memanggil SQLite.
class FakeNotesNotifier extends NotesNotifier {
  @override
  NotesState build() {
    return NotesState(
      notes: [
        Note(id: 1, title: 'Belanja Bulanan', updatedAt: DateTime(2026, 10, 1)),
        Note(
          id: 2,
          title: 'belajar riverpod',
          updatedAt: DateTime(2026, 10, 2),
        ),
        Note(
          id: 3,
          title: 'Belajar Clean Architecture',
          updatedAt: DateTime(2026, 10, 4),
        ),
      ],
    );
  }
}

/// Auth palsu: user sudah login agar NotesPage tidak redirect.
class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(
      user: User(id: 'u1', email: 'mhs@polinema.ac.id', name: 'Mahasiswa'),
      isLoading: false,
    );
  }
}

Widget _buildSubject() {
  return ProviderScope(
    overrides: [
      notesNotifierProvider.overrideWith(FakeNotesNotifier.new),
      authStateProvider.overrideWith(FakeAuthNotifier.new),
    ],
    child: const MaterialApp(home: NotesPage()),
  );
}

void main() {
  testWidgets('query tak cocok menampilkan empty state "Tidak ada catatan"', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();

    // Awalnya: ketiga catatan tampil, empty state belum ada.
    expect(find.text('Belanja Bulanan'), findsOneWidget);
    expect(find.byKey(const Key('notesSearchEmptyState')), findsNothing);

    // Ketik query yang tidak cocok dengan judul mana pun.
    await tester.enterText(
      find.byKey(const Key('notesSearchField')),
      'zzz-tak-ada',
    );
    await tester.pumpAndSettle();

    // Empty state muncul dan daftar hilang.
    expect(find.byKey(const Key('notesSearchEmptyState')), findsOneWidget);
    expect(find.text('Tidak ada catatan yang cocok'), findsOneWidget);
    expect(find.text('Belanja Bulanan'), findsNothing);
  });

  testWidgets('query cocok (case-insensitive) memfilter daftar', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('notesSearchField')),
      'belajar',
    );
    await tester.pumpAndSettle();

    // Hanya 2 judul mengandung "belajar" (huruf besar/kecil diabaikan).
    expect(find.text('belajar riverpod'), findsOneWidget);
    expect(find.text('Belajar Clean Architecture'), findsOneWidget);
    expect(find.text('Belanja Bulanan'), findsNothing);
    expect(find.byKey(const Key('notesSearchEmptyState')), findsNothing);
  });
}
