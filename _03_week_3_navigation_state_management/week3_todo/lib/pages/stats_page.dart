import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/stats_provider.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch di dalam build agar UI ter-rebuild saat state berubah
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistik AI')),
      // Menggunakan when untuk memastikan ketiga state tertangani
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Terjadi Kesalahan:\n$err', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                // ref.read di dalam callback untuk memanggil aksi tanpa berlangganan
                onPressed: () => ref.read(statsProvider.notifier).refresh(),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
        data: (stats) => ListView.builder(
          itemCount: stats.length,
          itemBuilder: (context, index) => ListTile(
            leading: const Icon(Icons.analytics),
            title: Text(stats[index]),
          ),
        ),
      ),
    );
  }
}