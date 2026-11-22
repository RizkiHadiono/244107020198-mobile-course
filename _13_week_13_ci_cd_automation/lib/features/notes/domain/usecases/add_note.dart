import '../../../../core/failures.dart';
import '../../../../core/validation/note_validator.dart';
import '../entities/note.dart';
import '../repositories/note_repository.dart';

class AddNote {
  const AddNote(this._repository);
  final NoteRepository _repository;

  Future<({Note? note, Failure? failure})> call({
    required String title,
    String body = '',
  }) async {
    // Week 12: aturan validasi dipusatkan di `noteTitleError` supaya UI dan
    // domain memakai aturan yang sama (termasuk batas panjang judul).
    final titleError = noteTitleError(title);
    if (titleError != null) {
      return (note: null, failure: ValidationFailure(titleError));
    }
    return _repository.addNote(title: title.trim(), body: body.trim());
  }
}
