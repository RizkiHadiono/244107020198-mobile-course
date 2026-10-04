import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();

class AuthNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    // Otomatis mengecek status login saat provider pertama kali dimuat
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    // Mock API Call delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Mock save tokens
    await _storage.write(key: 'access_token', value: 'dummy_access_token');
    await _storage.write(key: 'refresh_token', value: 'dummy_refresh_token');
    
    state = const AsyncValue.data(true);
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    state = const AsyncValue.data(false);
  }
}

final authStateProvider = AsyncNotifierProvider<AuthNotifier, bool>(() {
  return AuthNotifier();
});