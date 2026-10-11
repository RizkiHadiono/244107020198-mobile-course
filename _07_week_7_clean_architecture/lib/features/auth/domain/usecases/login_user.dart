import '../../../../core/failures.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class LoginUser {
  const LoginUser(this._repository);
  final AuthRepository _repository;

  Future<({User? user, Failure? failure})> call({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (!cleanEmail.contains('@')) {
      return (
        user: null,
        failure: const ValidationFailure('Format email tidak valid (harus mengandung @)'),
      );
    }

    if (password.length < 6) {
      return (
        user: null,
        failure: const ValidationFailure('Kata sandi minimal 6 karakter'),
      );
    }

    return _repository.login(email: cleanEmail, password: password);
  }
}
