import '../entities/note.dart';
import '../../../../core/format.dart';

/// Use case domain untuk pencarian catatan berdasarkan judul.
/// Murni Dart: tanpa Flutter, SQLite, atau Dio — mematuhi dependency rule.
class SearchNotes {
  const SearchNotes();

  List<Note> call(List<Note> notes, String query) {
    return filterByTitle<Note>(notes, query, (note) => note.title);
  }
}
