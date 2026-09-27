import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/prefs.dart';

// --- 1. PROVIDER & NOTIFIER ---
final prefsRepositoryProvider = Provider((ref) => PrefsRepository());

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

// --- 2. UI HALAMAN PENGATURAN ---
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Memantau state mode gelap
    final darkModeAsync = ref.watch(darkModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: darkModeAsync.when(
        data: (isDark) {
          return Column(
            children: [
              SwitchListTile(
                title: const Text('Mode Gelap'),
                subtitle: const Text('Aktifkan tema gelap untuk aplikasi'),
                value: isDark,
                onChanged: (value) {
                  // Memanggil fungsi toggle() saat saklar ditekan
                  ref.read(darkModeProvider.notifier).toggle();
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}