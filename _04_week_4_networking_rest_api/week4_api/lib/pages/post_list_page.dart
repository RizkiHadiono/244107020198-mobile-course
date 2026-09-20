import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/network_errors.dart';
import '../data/paged_posts.dart';
import 'post_tile.dart';

class PostListPage extends ConsumerStatefulWidget {
  const PostListPage({super.key});

  @override
  ConsumerState<PostListPage> createState() => _PostListPageState();
}

class _PostListPageState extends ConsumerState<PostListPage> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      if (_controller.position.pixels >=
          _controller.position.maxScrollExtent - 200) {
        ref.read(pagedPostsProvider.notifier).loadNextPage();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pagedPostsProvider);

    if (state.error != null && state.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Posts API'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off,
                  size: 60,
                ),
                const SizedBox(height: 16),
                Text(
                  friendlyErrorMessage(state.error!),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    ref
                        .read(pagedPostsProvider.notifier)
                        .loadFirstPage();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Posts API'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts API'),
        actions: [
          IconButton(
            onPressed: () {
              ref
                  .read(pagedPostsProvider.notifier)
                  .loadFirstPage();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref
              .read(pagedPostsProvider.notifier)
              .loadFirstPage();
        },
        child: ListView.builder(
          controller: _controller,
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: state.items.length + 1,
          itemBuilder: (context, index) {
            if (index == state.items.length) {
              if (!state.hasMore) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline),
                        SizedBox(height: 8),
                        Text('Semua data termuat.'),
                      ],
                    ),
                  ),
                );
              }

              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final post = state.items[index];

            return PostTile(post: post);
          },
        ),
      ),
    );
  }
}