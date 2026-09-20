import 'package:flutter_test/flutter_test.dart';
import 'package:week4_api/data/models/comment.dart';

void main() {
  test('Comment.fromJson aman ketika field hilang', () {
    final comment = Comment.fromJson({
      'postId': 1,
      'id': 1,
      'name': 'Test User',
    });

    expect(comment.postId, 1);
    expect(comment.id, 1);
    expect(comment.name, 'Test User');
    expect(comment.email, '');
    expect(comment.body, '');
  });
}