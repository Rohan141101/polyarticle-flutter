import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _darkMode = false;
  bool _haptics = true;
  bool _loaded = false;

  bool get darkMode => _darkMode;
  bool get haptics => _haptics;
  bool get loaded => _loaded;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _darkMode = prefs.getBool('darkMode') ?? false;
      _haptics = prefs.getBool('haptics') ?? true;
    } catch (_) {
      // fall back to defaults
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('darkMode', value);
    } catch (_) {}
  }

  Future<void> setHaptics(bool value) async {
    _haptics = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('haptics', value);
    } catch (_) {}
  }
}
