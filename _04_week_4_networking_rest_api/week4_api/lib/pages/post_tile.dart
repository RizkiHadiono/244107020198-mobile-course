import 'package:flutter/material.dart';
import '../data/models/post.dart';
import 'package:go_router/go_router.dart';

class PostTile extends StatelessWidget {
  const PostTile({
    super.key,
    required this.post,
  });

  final Post post;

  @override
  Widget build(BuildContext context) {
  return ListTile(
    leading: CircleAvatar(
      child: Text(post.id.toString()),
    ),
    title: Text(
      post.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Text(
      post.body,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    onTap: () {
      context.push(
        '/post/${post.id}',
        extra: post,
      );
    },
  );
  }
}