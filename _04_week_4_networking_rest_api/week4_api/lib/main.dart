import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'data/models/post.dart';
import 'pages/post_detail_page.dart';
import 'pages/post_list_page.dart';

void main() => runApp(const ProviderScope(child: MyApp()));

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const PostListPage(),
        ),
        GoRoute(
          path: '/post/:id',
          builder: (context, state) {
            final post = state.extra as Post;

            return PostDetailPage(post: post);
          },
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Week 4 - REST API',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}