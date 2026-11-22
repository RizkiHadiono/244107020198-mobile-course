import '../../../../core/failures.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<({User? user, Failure? failure})> login({
    required String email,
    required String password,
  });

  Future<({bool success, Failure? failure})> logout();

  Future<({User? user, Failure? failure})> getCurrentUser();
}
