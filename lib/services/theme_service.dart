import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  ThemeService._internal();
  static final ThemeService instance = ThemeService._internal();
  factory ThemeService() => instance;

  static const _key = 'theme_mode';
  bool _isDark = false;
  bool _initialized = false;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getString(_key) == 'dark';
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _isDark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> toggle() async => setDark(!_isDark);
}
