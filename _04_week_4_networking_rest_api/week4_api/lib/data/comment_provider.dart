import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'models/comment.dart';
import 'repositories/comment_repository.dart';

final commentRepositoryProvider = Provider<CommentRepository>(
  (ref) => CommentRepository(createDio()),
);

class CommentsNotifier extends AsyncNotifier<List<Comment>> {
  @override
  Future<List<Comment>> build() async {
    final repository = ref.watch(commentRepositoryProvider);
    return repository.fetchComments(1);
  }
}

final commentsProvider =
    AsyncNotifierProvider<CommentsNotifier, List<Comment>>(
  CommentsNotifier.new,
);

String commentFriendlyErrorMessage(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Koneksi lambat atau timeout. Periksa internet Anda lalu coba lagi.';

      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server. Periksa internet Anda.';

      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;

        if (code == 404) {
          return 'Data tidak ditemukan (404).';
        }

        if (code == 500) {
          return 'Server mengalami masalah (500). Coba lagi nanti.';
        }

        return 'Server bermasalah ($code). Coba lagi nanti.';

      default:
        return 'Terjadi kesalahan jaringan. Coba lagi.';
    }
  }

  return 'Terjadi kesalahan tak terduga: $error';
}