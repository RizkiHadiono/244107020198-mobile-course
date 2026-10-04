import 'package:dio/dio.dart';

String getFriendlyErrorMessage(DioException error) {
  if (error.response?.statusCode == 401) {
    return 'Sesi habis, silakan masuk kembali.';
  }
  
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return 'Koneksi lambat, coba lagi nanti.';
    case DioExceptionType.connectionError:
      return 'Anda sedang offline. Periksa koneksi internet.';
    default:
      return 'Terjadi kesalahan pada server.';
  }
}