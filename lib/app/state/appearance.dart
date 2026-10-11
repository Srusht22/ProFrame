import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light, dark, or whichever the device is set to.
///
/// It follows the device until the user says otherwise, and what they say
/// is kept on the device, so the application opens the way they left it.
final appearanceProvider = NotifierProvider<Appearance, ThemeMode>(
  Appearance.new,
);

class Appearance extends Notifier<ThemeMode> {
  /// Where the choice is kept.
  static const key = 'proframe.appearance';

  /// Each choice's mark, in the order they are offered. What each is
  /// called is the language's (`appearanceLabel`).
  static const icons = {
    ThemeMode.system: Icons.brightness_auto_outlined,
    ThemeMode.light: Icons.light_mode_outlined,
    ThemeMode.dark: Icons.dark_mode_outlined,
  };

  /// Whether the user has chosen since this was built, so a choice made
  /// while the kept one is still being read is not overwritten by it.
  bool _chosen = false;

  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final kept = prefs.getString(key);
      if (_chosen || kept == null) return;
      for (final mode in ThemeMode.values) {
        if (mode.name == kept) state = mode;
      }
    } on Object {
      // Nothing kept, or nowhere to keep it: follow the device.
    }
  }

  Future<void> choose(ThemeMode mode) async {
    _chosen = true;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, mode.name);
    } on Object {
      // Keeping it is a convenience; the choice stands for this session.
    }
  }
}
