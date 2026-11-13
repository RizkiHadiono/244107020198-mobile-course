import 'package:week12_testing_quality_assurance/core/failures.dart';
import 'package:week12_testing_quality_assurance/features/auth/domain/entities/user.dart';
import 'package:week12_testing_quality_assurance/features/auth/domain/repositories/auth_repository.dart';
import 'package:week12_testing_quality_assurance/features/notes/domain/entities/note.dart';
import 'package:week12_testing_quality_assurance/features/notes/domain/repositories/note_repository.dart';

/// Fake repository catatan.
///
/// Semua dependensi eksternal (SQLite) diganti dengan koleksi di memori
/// sehingga pengujian:
/// - tidak menyentuh disk maupun plugin platform,
/// - dapat memaksa kondisi sukses maupun gagal secara deterministik,
/// - dapat menghitung berapa kali sebuah operasi dipanggil.
///
/// [fetchFailure] dan kawan-kawan sengaja mutable agar satu test dapat
/// mensimulasikan "gagal dulu, lalu pulih" (skenario tombol Coba Lagi).
class FakeNoteRepository implements NoteRepository {
  FakeNoteRepository({
    List<Note>? notes,
    this.fetchFailure,
    this.searchFailure,
    this.countFailure,
    this.addFailure,
    this.updateFailure,
    this.deleteFailure,
    this.syncFailure,
    this.latency = Duration.zero,
  }) : _notes = [...?notes];

  final List<Note> _notes;

  /// Jeda buatan untuk menguji indikator loading.
  Duration latency;

  Failure? fetchFailure;
  Failure? searchFailure;
  Failure? countFailure;
  Failure? addFailure;
  Failure? updateFailure;
  Failure? deleteFailure;
  Failure? syncFailure;

  int fetchCalls = 0;
  int searchCalls = 0;
  int countCalls = 0;
  int addCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  int countDirtyCalls = 0;
  int syncCalls = 0;

  int _nextId = 1000;

  /// Parameter pagination terakhir yang diterima, untuk memastikan UI benar
  /// benar meminta halaman berikutnya (bukan memuat seluruh tabel).
  int? lastLimit;
  int? lastOffset;

  List<Note> get notes => List.unmodifiable(_notes);

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes({
    int limit = 20,
    int offset = 0,
  }) async {
    fetchCalls++;
    lastLimit = limit;
    lastOffset = offset;
    await _wait();
    if (fetchFailure != null) {
      return (notes: const <Note>[], failure: fetchFailure);
    }
    final sorted = [..._notes]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final page = sorted.skip(offset).take(limit).toList(growable: false);
    return (notes: page, failure: null);
  }

  @override
  Future<({List<Note> notes, Failure? failure})> searchNotes(
    String query,
  ) async {
    searchCalls++;
    await _wait();
    if (searchFailure != null) {
      return (notes: const <Note>[], failure: searchFailure);
    }
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return (notes: const <Note>[], failure: null);
    final matches = _notes
        .where((n) => n.title.toLowerCase().contains(q))
        .toList(growable: false);
    return (notes: matches, failure: null);
  }

  @override
  Future<({int total, Failure? failure})> countNotes() async {
    countCalls++;
    await _wait();
    if (countFailure != null) return (total: 0, failure: countFailure);
    return (total: _notes.length, failure: null);
  }

  @override
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  }) async {
    addCalls++;
    await _wait();
    if (addFailure != null) return (note: null, failure: addFailure);
    final note = Note(
      id: _nextId++,
      title: title,
      body: body,
      updatedAt: DateTime.now(),
      dirty: true,
    );
    _notes.add(note);
    return (note: note, failure: null);
  }

  @override
  Future<({bool success, Failure? failure})> updateNote(Note note) async {
    updateCalls++;
    await _wait();
    if (updateFailure != null) return (success: false, failure: updateFailure);
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index == -1) {
      return (
        success: false,
        failure: const LocalFailure('Catatan tidak ditemukan'),
      );
    }
    _notes[index] = note;
    return (success: true, failure: null);
  }

  @override
  Future<({bool success, Failure? failure})> deleteNote(int id) async {
    deleteCalls++;
    await _wait();
    if (deleteFailure != null) return (success: false, failure: deleteFailure);
    _notes.removeWhere((n) => n.id == id);
    return (success: true, failure: null);
  }

  @override
  Future<({int count, Failure? failure})> countDirty() async {
    countDirtyCalls++;
    await _wait();
    return (count: _notes.where((n) => n.dirty).length, failure: null);
  }

  @override
  Future<({bool success, Failure? failure})> syncNotes() async {
    syncCalls++;
    await _wait();
    if (syncFailure != null) return (success: false, failure: syncFailure);
    for (var i = 0; i < _notes.length; i++) {
      _notes[i] = _notes[i].copyWith(dirty: false);
    }
    return (success: true, failure: null);
  }
}

/// Fake repository autentikasi.
///
/// Tidak memakai `SharedPreferences`, sehingga widget test tidak perlu
/// menyiapkan plugin platform.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.currentUser,
    this.loginFailure,
    this.logoutFailure,
    this.latency = Duration.zero,
  });

  User? currentUser;
  Failure? loginFailure;
  Failure? logoutFailure;
  Duration latency;

  int loginCalls = 0;
  int logoutCalls = 0;
  int getCurrentUserCalls = 0;

  String? lastEmail;
  String? lastPassword;

  @override
  Future<({User? user, Failure? failure})> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    lastEmail = email;
    lastPassword = password;
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (loginFailure != null) return (user: null, failure: loginFailure);
    final user = User(
      id: 'usr_test',
      email: email,
      name: email.split('@').first.toUpperCase(),
      token: 'token-test',
    );
    currentUser = user;
    return (user: user, failure: null);
  }

  @override
  Future<({bool success, Failure? failure})> logout() async {
    logoutCalls++;
    if (logoutFailure != null) {
      return (success: false, failure: logoutFailure);
    }
    currentUser = null;
    return (success: true, failure: null);
  }

  @override
  Future<({User? user, Failure? failure})> getCurrentUser() async {
    getCurrentUserCalls++;
    return (user: currentUser, failure: null);
  }
}
