import '../../../../core/failures.dart';
import '../entities/note.dart';
import '../repositories/note_repository.dart';

class AddNote {
  const AddNote(this._repository);
  final NoteRepository _repository;

  Future<({Note? note, Failure? failure})> call({
    required String title,
    String body = '',
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return (
        note: null,
        failure: const ValidationFailure('Judul catatan tidak boleh kosong'),
      );
    }
    return _repository.addNote(title: trimmedTitle, body: body.trim());
  }
}
