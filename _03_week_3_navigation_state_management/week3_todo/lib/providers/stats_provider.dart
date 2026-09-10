import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

class DashboardStats {
  final int totalTasks;
  final int completedTasks;
  final double completionRate;

  DashboardStats({
    required this.totalTasks,
    required this.completedTasks,
    required this.completionRate,
  });
}

class StatsAsyncNotifier extends AsyncNotifier<DashboardStats> {
  @override
  Future<DashboardStats> build() async {
    return _fetchStats();
  }

  Future<DashboardStats> _fetchStats() async {
    await Future.delayed(const Duration(seconds: 2));
    if (Random().nextDouble() < 0.3) {
      throw Exception('Koneksi server statistik terputus.');
    }
    return DashboardStats(
      totalTasks: 12,
      completedTasks: 9,
      completionRate: 75.0,
    );
  }

  Future<void> refreshStats() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchStats());
  }
}

final statsAsyncProvider = AsyncNotifierProvider<StatsAsyncNotifier, DashboardStats>(StatsAsyncNotifier.new);