import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Deklarasi provider ditambahkan di sini agar bisa diakses dari semua halaman
final prefsRepositoryProvider = Provider((ref) => PrefsRepository());

class PrefsRepository {
  static const String _darkModeKey = 'dark_mode';
  static const String _lastOpenedKey = 'last_opened';

  // --- Preferensi Tema ---
  Future<void> setDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDark);
  }

  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  // --- Waktu Terakhir Dibuka ---
  Future<void> saveLastOpenedTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastOpenedKey, DateTime.now().toIso8601String());
  }

  Future<String?> getLastOpenedTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastOpenedKey);
  }
}