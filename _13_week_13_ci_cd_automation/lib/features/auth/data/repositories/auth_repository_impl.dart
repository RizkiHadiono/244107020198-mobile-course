import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({Future<SharedPreferences> Function()? getPrefs})
    : _getPrefs = getPrefs ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _getPrefs;
  static const _keyToken = 'auth_token';
  static const _keyEmail = 'auth_email';
  static const _keyName = 'auth_name';
  static const _keyId = 'auth_id';

  @override
  Future<({User? user, Failure? failure})> login({
    required String email,
    required String password,
  }) async {
    try {
      // Simulasi panggilan jaringan (remote auth)
      await Future<void>.delayed(const Duration(milliseconds: 500));

      if (password == 'wrongpassword') {
        return (
          user: null,
          failure: const AuthFailure('Email atau kata sandi salah'),
        );
      }

      final token =
          'jwt-token-session-${DateTime.now().millisecondsSinceEpoch}';
      final username = email.split('@').first;
      final userId = 'usr_${email.hashCode.abs()}';

      final userModel = UserModel(
        id: userId,
        email: email,
        name: username.toUpperCase(),
        token: token,
      );

      final prefs = await _getPrefs();
      await prefs.setString(_keyToken, token);
      await prefs.setString(_keyEmail, email);
      await prefs.setString(_keyName, userModel.name);
      await prefs.setString(_keyId, userId);

      return (user: userModel.toEntity(), failure: null);
    } catch (e) {
      return (
        user: null,
        failure: NetworkFailure('Gagal terhubung ke server autentikasi: $e'),
      );
    }
  }

  @override
  Future<({bool success, Failure? failure})> logout() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyEmail);
      await prefs.remove(_keyName);
      await prefs.remove(_keyId);
      return (success: true, failure: null);
    } catch (e) {
      return (
        success: false,
        failure: LocalFailure('Gagal membersihkan sesi lokal: $e'),
      );
    }
  }

  @override
  Future<({User? user, Failure? failure})> getCurrentUser() async {
    try {
      final prefs = await _getPrefs();
      final token = prefs.getString(_keyToken);
      if (token == null || token.isEmpty) {
        return (user: null, failure: null);
      }

      final email = prefs.getString(_keyEmail) ?? '';
      final name = prefs.getString(_keyName) ?? '';
      final id = prefs.getString(_keyId) ?? '';

      final model = UserModel(id: id, email: email, name: name, token: token);
      return (user: model.toEntity(), failure: null);
    } catch (e) {
      return (
        user: null,
        failure: LocalFailure('Gagal memuat sesi pengguna: $e'),
      );
    }
  }
}
