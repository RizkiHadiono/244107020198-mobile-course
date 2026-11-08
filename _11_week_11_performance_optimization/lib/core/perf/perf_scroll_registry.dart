import 'package:flutter/widgets.dart';

/// Menyimpan referensi `ScrollController` yang sedang aktif agar skenario
/// profiling otomatis dapat menggulir daftar tanpa perlu menebak koordinat
/// pointer. Hanya diisi ketika `PERF_MODE` aktif.
class PerfScrollRegistry {
  PerfScrollRegistry._();

  static final PerfScrollRegistry instance = PerfScrollRegistry._();

  ScrollController? primary;

  /// Controller kolom pencarian daftar catatan (untuk screenshot kondisi
  /// "sedang mencari").
  TextEditingController? searchField;

  void register(ScrollController controller) {
    primary = controller;
  }

  void unregister(ScrollController controller) {
    if (identical(primary, controller)) primary = null;
  }

  void registerSearch(TextEditingController controller) {
    searchField = controller;
  }

  void unregisterSearch(TextEditingController controller) {
    if (identical(searchField, controller)) searchField = null;
  }
}
