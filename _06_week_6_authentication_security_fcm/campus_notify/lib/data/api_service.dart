import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/auth_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.kampus.edu/v1/'));
  const storage = FlutterSecureStorage();

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await storage.read(key: 'access_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (DioException e, handler) async {
      if (e.response?.statusCode == 401) {
        // Logika Refresh Token
        final refreshToken = await storage.read(key: 'refresh_token');
        if (refreshToken != null) {
          try {
            // Mock request ke endpoint refresh token
            // final response = await dio.post('/auth/refresh', data: {'token': refreshToken});
            
            // Simulasi mendapat token baru
            const newAccessToken = 'new_dummy_access_token';
            await storage.write(key: 'access_token', value: newAccessToken);
            
            // Ulangi request yang gagal
            e.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
            final cloneReq = await dio.fetch(e.requestOptions);
            return handler.resolve(cloneReq);
          } catch (refreshError) {
            // Refresh token mati/gagal -> Paksa logout
            ref.read(authStateProvider.notifier).logout();
          }
        } else {
          ref.read(authStateProvider.notifier).logout();
        }
      }
      return handler.next(e);
    },
  ));

  return dio;
});