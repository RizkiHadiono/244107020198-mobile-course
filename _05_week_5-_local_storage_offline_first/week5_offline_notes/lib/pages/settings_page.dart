import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/prefs.dart';

// Provider tambahan untuk membaca waktu terakhir dibuka
final lastOpenedProvider = FutureProvider<String?>((ref) async {
  return ref.watch(prefsRepositoryProvider).getLastOpenedTime();
});

final darkModeProvider = AsyncNotifierProvider<DarkModeNotifier, bool>(DarkModeNotifier.new);

class DarkModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(prefsRepositoryProvider).getDarkMode();

  Future<void> toggle() async {
    final next = !(state.value ?? false);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(prefsRepositoryProvider).setDarkMode(next);
      return next;
    });
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkModeAsync = ref.watch(darkModeProvider);
    final lastOpenedAsync = ref.watch(lastOpenedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('PREFERENSI APLIKASI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          darkModeAsync.when(
            data: (isDark) => SwitchListTile(
              secondary: const Icon(Icons.dark_mode),
              title: const Text('Mode Gelap'),
              subtitle: const Text('Aktifkan tema gelap untuk aplikasi'),
              value: isDark,
              onChanged: (value) => ref.read(darkModeProvider.notifier).toggle(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => ListTile(title: Text('Error: $e')),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('INFORMASI SISTEM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          lastOpenedAsync.when(
            data: (time) {
              final displayTime = time != null 
                  ? DateTime.parse(time).toLocal().toString().split('.')[0] 
                  : 'Belum ada data';
              return ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Terakhir Dibuka'),
                subtitle: Text(displayTime),
              );
            },
            loading: () => const ListTile(title: Text('Memuat...')),
            error: (e, s) => ListTile(title: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}