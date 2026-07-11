// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_controller.g.dart';

/// Persists the in-app theme override (#160). Same seam shape as
/// `LocaleStore` so widget tests never touch platform channels.
abstract class ThemeStore {
  /// The stored mode ('light' or 'dark') or null for "follow the system".
  Future<String?> read();

  /// Persists [mode]; null removes the override.
  Future<void> write(String? mode);
}

class PrefsThemeStore implements ThemeStore {
  static const _key = 'theme_mode_override';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String? mode) async {
    final prefs = await SharedPreferences.getInstance();
    if (mode == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, mode);
    }
  }
}

@Riverpod(keepAlive: true)
ThemeStore themeStore(Ref ref) => PrefsThemeStore();

/// The user's theme override; null means "follow the system brightness".
/// Feeding this into `MaterialApp.themeMode` applies a change instantly,
/// no restart needed.
@Riverpod(keepAlive: true)
class ThemeController extends _$ThemeController {
  static const _light = 'light';
  static const _dark = 'dark';

  @override
  Future<ThemeMode?> build() async {
    final stored = await ref.watch(themeStoreProvider).read();
    return switch (stored) {
      _light => ThemeMode.light,
      _dark => ThemeMode.dark,
      _ => null,
    };
  }

  Future<void> set(ThemeMode? mode) async {
    // ThemeMode.system and null both mean "no override" — normalize so
    // state keeps the invariant "null = follow the system".
    final normalized = mode == ThemeMode.system ? null : mode;
    state = AsyncData(normalized);
    await ref.read(themeStoreProvider).write(switch (normalized) {
      ThemeMode.light => _light,
      ThemeMode.dark => _dark,
      _ => null,
    });
  }
}
