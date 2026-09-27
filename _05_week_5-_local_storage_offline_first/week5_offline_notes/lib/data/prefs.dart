import 'package:shared_preferences/shared_preferences.dart';

class PrefsRepository {
  static const String _darkModeKey = 'dark_mode';

  // Menyimpan preferensi tema ke SharedPreferences
  Future<void> setDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDark);
  }

  // Mengambil preferensi tema dari SharedPreferences
  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false; // Default: false (Light Mode)
  }
}