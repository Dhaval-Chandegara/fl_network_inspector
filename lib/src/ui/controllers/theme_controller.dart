import 'package:flutter/material.dart';

/// Local theme controller for managing theme mode within the inspector UI (defaults to dark mode).
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController([super.value = ThemeMode.dark]);

  /// Cycles theme mode: Dark -> Light -> System -> Dark.
  void toggleTheme() {
    switch (value) {
      case ThemeMode.dark:
        value = ThemeMode.light;
        break;
      case ThemeMode.light:
        value = ThemeMode.system;
        break;
      case ThemeMode.system:
        value = ThemeMode.dark;
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
