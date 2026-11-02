import 'package:flutter/material.dart';

/// Local theme controller for toggling light/dark/system theme within the inspector UI (D-50).
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController([super.value = ThemeMode.system]);

  /// Cycles theme mode: System -> Light -> Dark -> System.
  void toggleTheme() {
    switch (value) {
      case ThemeMode.system:
        value = ThemeMode.light;
        break;
      case ThemeMode.light:
        value = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        value = ThemeMode.system;
        break;
    }
  }

  /// Sets the theme explicitly.
  void setTheme(ThemeMode mode) {
    if (value != mode) {
      value = mode;
    }
  }
}
