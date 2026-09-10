import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

// Menggunakan AsyncNotifier untuk state asinkron
class StatsNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    return _fetchData();
  }

  Future<List<String>> _fetchData() async {
    await Future.delayed(const Duration(seconds: 2)); // Simulasi network 2 detik
    
    // Simulasi kadang gagal 30%
    if (Random().nextDouble() < 0.3) {
      throw Exception('Gagal mengambil data statistik dari server (Error 30%)');
    }

    return ['Tugas Selesai: 12', 'Tugas Tertunda: 4', 'Efisiensi: 85%'];
  }

  // Fungsi untuk memuat ulang data saat tombol 'Coba lagi' ditekan
  Future<void> refresh() async {
    state = const AsyncLoading(); // Set ke loading
    state = await AsyncValue.guard(() => _fetchData()); // Guard otomatis tangkap error
  }
}

// Deklarasi provider dengan tipe eksplisit
final statsProvider = AsyncNotifierProvider<StatsNotifier, List<String>>(StatsNotifier.new);