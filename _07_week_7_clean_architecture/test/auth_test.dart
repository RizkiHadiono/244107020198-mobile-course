import 'package:flutter_test/flutter_test.dart';
import 'package:week7_clean_architecture/core/failures.dart';
import 'package:week7_clean_architecture/features/auth/domain/entities/user.dart';
import 'package:week7_clean_architecture/features/auth/domain/repositories/auth_repository.dart';
import 'package:week7_clean_architecture/features/auth/domain/usecases/login_user.dart';
import 'package:week7_clean_architecture/features/auth/domain/usecases/logout_user.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.fail = false});

  final bool fail;
  bool isLoggedOut = false;

  @override
  Future<({User? user, Failure? failure})> login({
    required String email,
    required String password,
  }) async {
    if (fail) {
      return (
        user: null,
        failure: const AuthFailure('Kredensial tidak valid'),
      );
    }
    return (
      user: User(
        id: 'usr_1',
        email: email,
        name: 'Mahasiswa Test',
        token: 'token-fake-123',
      ),
      failure: null,
    );
  }

  @override
  Future<({bool success, Failure? failure})> logout() async {
    isLoggedOut = true;
    return (success: true, failure: null);
  }

  @override
  Future<({User? user, Failure? failure})> getCurrentUser() async {
    return (user: null, failure: null);
  }
}

void main() {
  group('LoginUser UseCase Tests (Business Validation & Fake Repo)', () {
    test('LoginUser menolak format email tanpa simbol @', () async {
      final repo = FakeAuthRepository();
      final useCase = LoginUser(repo);

      final result = await useCase(
        email: 'invalid-email',
        password: 'password123',
      );

      expect(result.user, isNull);
      expect(result.failure, isA<ValidationFailure>());
      expect(result.failure!.message, contains('@'));
    });

    test('LoginUser menolak kata sandi kurang dari 6 karakter', () async {
      final repo = FakeAuthRepository();
      final useCase = LoginUser(repo);

      final result = await useCase(
        email: 'user@polinema.ac.id',
        password: '123',
      );

      expect(result.user, isNull);
      expect(result.failure, isA<ValidationFailure>());
      expect(result.failure!.message, contains('minimal 6 karakter'));
    });

    test('LoginUser berhasil mengembalikan User entity saat kredensial valid', () async {
      final repo = FakeAuthRepository();
      final useCase = LoginUser(repo);

      final result = await useCase(
        email: 'student@polinema.ac.id',
        password: 'secretPassword123',
      );

      expect(result.failure, isNull);
      expect(result.user, isNotNull);
      expect(result.user!.email, 'student@polinema.ac.id');
      expect(result.user!.isAuthenticated, isTrue);
    });
  });

  group('LogoutUser UseCase Tests', () {
    test('LogoutUser mengeksekusi proses logout pada repository', () async {
      final repo = FakeAuthRepository();
      final useCase = LogoutUser(repo);

      final result = await useCase();

      expect(result.success, isTrue);
      expect(repo.isLoggedOut, isTrue);
    });
  });
}
