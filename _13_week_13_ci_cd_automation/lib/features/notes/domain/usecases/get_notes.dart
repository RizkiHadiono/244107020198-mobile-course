import '../../../../core/failures.dart';
import '../entities/note.dart';
import '../repositories/note_repository.dart';

class GetNotes {
  const GetNotes(this._repository);
  final NoteRepository _repository;

  Future<({List<Note> notes, Failure? failure})> call({
    int limit = 20,
    int offset = 0,
  }) {
    return _repository.fetchNotes(limit: limit, offset: offset);
  }
}
