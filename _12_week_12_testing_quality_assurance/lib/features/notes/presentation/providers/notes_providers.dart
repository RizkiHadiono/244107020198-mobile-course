import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/notes_database.dart';
import '../../data/repositories/note_repository_impl.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../../domain/usecases/add_note.dart';
import '../../domain/usecases/get_notes.dart';
import '../../domain/usecases/search_notes.dart';
import '../../domain/usecases/update_note.dart';

/// Ukuran satu halaman daftar catatan (pagination).
const int kNotesPageSize = 20;

/// Data layer: NoteRepository abstraction injected with database opener
final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepositoryImpl(openDb: openNotesDb);
});

/// Domain layer: Use cases depend on repository interface (not implementation)
final getNotesProvider = Provider<GetNotes>((ref) {
  return GetNotes(ref.watch(noteRepositoryProvider));
});

final addNoteProvider = Provider<AddNote>((ref) {
  return AddNote(ref.watch(noteRepositoryProvider));
});

final updateNoteProvider = Provider<UpdateNote>((ref) {
  return UpdateNote(ref.watch(noteRepositoryProvider));
});

final searchNotesProvider = Provider<SearchNotes>((ref) {
  return const SearchNotes();
});

/// Dirty note count provider (monitoring sync queue)
final dirtyNotesCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(noteRepositoryProvider);
  final result = await repo.countDirty();
  if (result.failure != null) {
    throw Exception(result.failure!.message);
  }
  return result.count;
});

/// Presentation layer state class
class NotesState {
  const NotesState({
    required this.notes,
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.searchResults = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.total = 0,
  });

  final List<Note> notes;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;

  /// Hasil pencarian dari database (seluruh isi tabel, bukan hanya halaman
  /// yang sudah dimuat).
  final List<Note> searchResults;

  /// Apakah masih ada halaman berikutnya.
  final bool hasMore;
  final bool isLoadingMore;

  /// Jumlah total catatan di database (untuk label "x dari y").
  final int total;

  NotesState copyWith({
    List<Note>? notes,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    List<Note>? searchResults,
    bool? hasMore,
    bool? isLoadingMore,
    int? total,
  }) {
    return NotesState(
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      total: total ?? this.total,
    );
  }
}

/// Presentation layer: Notifier managing notes state
class NotesNotifier extends Notifier<NotesState> {
  int _searchToken = 0;

  @override
  NotesState build() {
    state = const NotesState(notes: [], isLoading: true);
    loadNotes();
    return state;
  }

  /// Memuat halaman pertama (dipakai saat inisialisasi dan pull-to-refresh).
  Future<void> loadNotes() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final getNotes = ref.read(getNotesProvider);
    final result = await getNotes(limit: kNotesPageSize, offset: 0);
    if (result.failure != null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.failure!.message,
      );
      return;
    }

    final totalResult = await ref.read(noteRepositoryProvider).countNotes();
    final total = totalResult.failure == null ? totalResult.total : result.notes.length;

    state = state.copyWith(
      notes: result.notes,
      isLoading: false,
      errorMessage: null,
      hasMore: result.notes.length == kNotesPageSize,
      total: total,
    );
  }

  /// Memuat halaman berikutnya (infinite scroll).
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoadingMore: true);
    final getNotes = ref.read(getNotesProvider);
    final result = await getNotes(
      limit: kNotesPageSize,
      offset: state.notes.length,
    );

    if (result.failure != null) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: result.failure!.message,
      );
      return;
    }

    state = state.copyWith(
      notes: [...state.notes, ...result.notes],
      isLoadingMore: false,
      hasMore: result.notes.length == kNotesPageSize,
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, searchResults: const []);
    if (query.trim().isEmpty) return;

    // Cari di seluruh database secara asinkron; UI tetap responsif karena
    // filter in-memory (visibleNotesProvider) langsung menampilkan hasil awal.
    _searchInRepository(query);
  }

  Future<void> _searchInRepository(String query) async {
    final token = ++_searchToken;
    try {
      final result = await ref
          .read(noteRepositoryProvider)
          .searchNotes(query.trim());
      if (token != _searchToken) return; // hasil usang, abaikan
      if (result.failure != null) return;
      state = state.copyWith(searchResults: result.notes);
    } catch (_) {
      // Abaikan: daftar yang sudah dimuat tetap difilter di memori.
    }
  }

  Future<bool> add({required String title, String body = ''}) async {
    final addNote = ref.read(addNoteProvider);
    final result = await addNote(title: title, body: body);
    if (result.failure != null) {
      state = state.copyWith(errorMessage: result.failure!.message);
      return false;
    }
    await loadNotes();
    ref.invalidate(dirtyNotesCountProvider);
    return true;
  }

  Future<bool> update(Note note) async {
    final updateNote = ref.read(updateNoteProvider);
    final result = await updateNote(note);
    if (result.failure != null) {
      state = state.copyWith(errorMessage: result.failure!.message);
      return false;
    }
    await loadNotes();
    ref.invalidate(dirtyNotesCountProvider);
    return true;
  }

  Future<bool> delete(int id) async {
    final repo = ref.read(noteRepositoryProvider);
    final result = await repo.deleteNote(id);
    if (result.failure != null) {
      state = state.copyWith(errorMessage: result.failure!.message);
      return false;
    }
    await loadNotes();
    ref.invalidate(dirtyNotesCountProvider);
    return true;
  }

  Future<bool> sync() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final repo = ref.read(noteRepositoryProvider);
    final result = await repo.syncNotes();
    if (result.failure != null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.failure!.message,
      );
      return false;
    }
    await loadNotes();
    ref.invalidate(dirtyNotesCountProvider);
    return true;
  }
}

final notesNotifierProvider = NotifierProvider<NotesNotifier, NotesState>(
  NotesNotifier.new,
);

/// Provider turunan (reaktif) yang HANYA bergantung pada daftar + query.
///
/// Dengan memakai `select`, perubahan `isLoading`/`errorMessage` tidak
/// memicu rebuild daftar.
final visibleNotesProvider = Provider<List<Note>>((ref) {
  final notes = ref.watch(notesNotifierProvider.select((s) => s.notes));
  final query = ref.watch(notesNotifierProvider.select((s) => s.searchQuery));
  final results = ref.watch(
    notesNotifierProvider.select((s) => s.searchResults),
  );

  if (query.trim().isEmpty) return notes;
  if (results.isNotEmpty) return results;
  return ref.read(searchNotesProvider).call(notes, query);
});

/// Potongan state untuk header ringkasan (jumlah catatan).
final notesTotalProvider = Provider<int>((ref) {
  return ref.watch(notesNotifierProvider.select((s) => s.total));
});
