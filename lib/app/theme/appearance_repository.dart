import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AppearanceRepository {
  Future<ThemeMode> read();
  Future<void> write(ThemeMode mode);
}

class LocalAppearanceRepository implements AppearanceRepository {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  static const _key = 'hyner.appearance';

  @override
  Future<ThemeMode> read() async {
    final value = await _preferences.getString(_key);
    return ThemeMode.values.where((mode) => mode.name == value).firstOrNull ??
        ThemeMode.system;
  }

  @override
  Future<void> write(ThemeMode mode) => _preferences.setString(_key, mode.name);
}
