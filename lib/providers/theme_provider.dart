import 'package:flutter/material.dart';

/// Lets the Profile screen's dark-mode switch actually control the
/// app, instead of only following the system setting.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  void toggleDark(bool dark) {
    _mode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void useSystem() {
    _mode = ThemeMode.system;
    notifyListeners();
  }
}
