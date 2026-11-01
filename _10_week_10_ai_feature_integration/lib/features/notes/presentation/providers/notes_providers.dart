import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/notes_database.dart';
import '../../data/repositories/note_repository_impl.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../../domain/usecases/add_note.dart';
import '../../domain/usecases/get_notes.dart';
import '../../domain/usecases/search_notes.dart';
import '../../domain/usecases/update_note.dart';

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
  });

  final List<Note> notes;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;

  NotesState copyWith({
    List<Note>? notes,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
  }) {
    return NotesState(
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Presentation layer: Notifier managing notes state
class NotesNotifier extends Notifier<NotesState> {
  @override
  NotesState build() {
    state = const NotesState(notes: [], isLoading: true);
    loadNotes();
    return state;
  }

  Future<void> loadNotes() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final getNotes = ref.read(getNotesProvider);
    final result = await getNotes();
    if (result.failure != null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.failure!.message,
      );
    } else {
      state = state.copyWith(
        notes: result.notes,
        isLoading: false,
        errorMessage: null,
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
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

/// Provider turunan (reaktif): daftar catatan terfilter oleh query pencarian.
/// UI me-watch provider ini, sehingga daftar otomatis ter-update saat
/// state.notes atau state.searchQuery berubah — bukan via ref.read getter.
final visibleNotesProvider = Provider<List<Note>>((ref) {
  final state = ref.watch(notesNotifierProvider);
  return ref.read(searchNotesProvider).call(state.notes, state.searchQuery);
});
