import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:week12_testing_quality_assurance/core/failures.dart';
import 'package:week12_testing_quality_assurance/features/auth/domain/entities/user.dart';
import 'package:week12_testing_quality_assurance/features/auth/presentation/providers/auth_providers.dart';
import 'package:week12_testing_quality_assurance/features/notes/domain/entities/note.dart';
import 'package:week12_testing_quality_assurance/features/notes/domain/repositories/note_repository.dart';
import 'package:week12_testing_quality_assurance/features/notes/presentation/providers/notes_providers.dart';
import 'package:week12_testing_quality_assurance/main.dart';

/// Repository yang selalu gagal, khusus untuk mendokumentasikan tampilan
/// keadaan error pada perangkat.
class FailingNoteRepository implements NoteRepository {
  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes({
    int limit = 20,
    int offset = 0,
  }) async {
    return (
      notes: const <Note>[],
      failure: const LocalFailure('Gagal membaca catatan dari database lokal'),
    );
  }

  @override
  Future<({List<Note> notes, Failure? failure})> searchNotes(String query) async {
    return (notes: const <Note>[], failure: null);
  }

  @override
  Future<({int total, Failure? failure})> countNotes() async {
    return (total: 0, failure: const LocalFailure('Database tidak tersedia'));
  }

  @override
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  }) async {
    return (note: null, failure: const LocalFailure('Database tidak tersedia'));
  }

  @override
  Future<({bool success, Failure? failure})> updateNote(Note note) async {
    return (success: false, failure: const LocalFailure('Database tidak tersedia'));
  }

  @override
  Future<({bool success, Failure? failure})> deleteNote(int id) async {
    return (success: false, failure: const LocalFailure('Database tidak tersedia'));
  }

  @override
  Future<({int count, Failure? failure})> countDirty() async {
    return (count: 0, failure: null);
  }

  @override
  Future<({bool success, Failure? failure})> syncNotes() async {
    return (success: false, failure: const LocalFailure('Database tidak tersedia'));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dokumentasi screenshot keadaan error', (tester) async {
    try {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    } catch (error) {
      debugPrint('convertFlutterSurfaceToImage tidak tersedia: $error');
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(FailingNoteRepository()),
          authStateProvider.overrideWith(FakeLoggedInAuth.new),
        ],
        child: const CleanArchitectureApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Gagal membaca catatan dari database lokal'), findsOneWidget);
    await binding.takeScreenshot('08-error-state');
  });
}

/// Auth palsu: pengguna dianggap sudah login agar langsung masuk daftar.
class FakeLoggedInAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    user: User(
      id: 'usr_qa',
      email: 'student@polinema.ac.id',
      name: 'STUDENT',
      token: 'token-qa',
    ),
  );
}
