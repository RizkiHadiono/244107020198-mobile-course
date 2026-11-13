import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _configureImageCache();
  runApp(const ProviderScope(child: CleanArchitectureApp()));
}

/// Week 11: batasi cache gambar agar memori tidak membengkak saat pengguna
/// menggulir daftar bergambar panjang.
///
/// Default Flutter: 1000 gambar / 100 MB. Untuk aplikasi ini 200 gambar /
/// 60 MB sudah lebih dari cukup dan menurunkan risiko OOM di perangkat
/// berspesifikasi rendah.
void _configureImageCache() {
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSize = 200;
  cache.maximumSizeBytes = 60 << 20; // 60 MB
}

class CleanArchitectureApp extends ConsumerWidget {
  const CleanArchitectureApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Clean Notes - Testing & QA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
      ),
      routerConfig: router,
    );
  }
}
