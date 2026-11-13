import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:week12_testing_quality_assurance/core/failures.dart';
import 'package:week12_testing_quality_assurance/features/auth/data/repositories/auth_repository_impl.dart';

/// Unit test repository autentikasi.
///
/// `shared_preferences` diganti penyimpanan tiruan resmi dari paketnya
/// (`setMockInitialValues`), sehingga test berjalan tanpa plugin platform dan
/// tanpa menyentuh berkas di perangkat.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthRepositoryImpl.login', () {
    test('menyimpan sesi dan mengembalikan user saat kredensial benar', () async {
      final repo = AuthRepositoryImpl();

      final result = await repo.login(
        email: 'mhs@polinema.ac.id',
        password: 'secret123',
      );

      expect(result.failure, isNull);
      expect(result.user, isNotNull);
      expect(result.user!.email, 'mhs@polinema.ac.id');
      expect(result.user!.name, 'MHS');
      expect(result.user!.token, isNotEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_email'), 'mhs@polinema.ac.id');
      expect(prefs.getString('auth_token'), isNotEmpty);
    });

    test('menolak kata sandi salah dengan AuthFailure', () async {
      final repo = AuthRepositoryImpl();

      final result = await repo.login(
        email: 'mhs@polinema.ac.id',
        password: 'wrongpassword',
      );

      expect(result.user, isNull);
      expect(result.failure, isA<AuthFailure>());
      expect(result.failure!.message, 'Email atau kata sandi salah');

      // Sesi tidak boleh tertulis saat login gagal.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
    });
  });

  group('AuthRepositoryImpl.getCurrentUser', () {
    test('mengembalikan null tanpa failure saat belum ada sesi', () async {
      final result = await AuthRepositoryImpl().getCurrentUser();

      expect(result.user, isNull);
      expect(result.failure, isNull);
    });

    test('memulihkan sesi yang tersimpan', () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'token-lama',
        'auth_email': 'lama@polinema.ac.id',
        'auth_name': 'LAMA',
        'auth_id': 'usr_lama',
      });

      final result = await AuthRepositoryImpl().getCurrentUser();

      expect(result.user, isNotNull);
      expect(result.user!.email, 'lama@polinema.ac.id');
      expect(result.user!.token, 'token-lama');
      expect(result.user!.isAuthenticated, isTrue);
    });
  });

  group('AuthRepositoryImpl.logout', () {
    test('menghapus seluruh kunci sesi', () async {
      final repo = AuthRepositoryImpl();
      await repo.login(email: 'mhs@polinema.ac.id', password: 'secret123');

      final result = await repo.logout();

      expect(result.success, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('auth_email'), isNull);
      expect(prefs.getString('auth_name'), isNull);
      expect(prefs.getString('auth_id'), isNull);
    });
  });

  group('AuthRepositoryImpl saat penyimpanan bermasalah', () {
    test('login mengembalikan NetworkFailure bila prefs gagal dibuka', () async {
      final repo = AuthRepositoryImpl(
        getPrefs: () async => throw Exception('penyimpanan tidak tersedia'),
      );

      final result = await repo.login(
        email: 'mhs@polinema.ac.id',
        password: 'secret123',
      );

      expect(result.user, isNull);
      expect(result.failure, isA<NetworkFailure>());
      expect(result.failure!.message, contains('Gagal terhubung'));
    });

    test('logout mengembalikan LocalFailure bila prefs gagal dibuka', () async {
      final repo = AuthRepositoryImpl(
        getPrefs: () async => throw Exception('penyimpanan tidak tersedia'),
      );

      final result = await repo.logout();

      expect(result.success, isFalse);
      expect(result.failure, isA<LocalFailure>());
    });

    test('getCurrentUser mengembalikan LocalFailure bila prefs gagal dibuka', () async {
      final repo = AuthRepositoryImpl(
        getPrefs: () async => throw Exception('penyimpanan tidak tersedia'),
      );

      final result = await repo.getCurrentUser();

      expect(result.user, isNull);
      expect(result.failure, isA<LocalFailure>());
    });
  });
}
