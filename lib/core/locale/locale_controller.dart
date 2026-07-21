// SPDX-License-Identifier: 0BSD
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'locale_controller.g.dart';

/// Persists the in-app language override (#147). Same seam shape as
/// `DevModeStore` so widget tests never touch platform channels.
abstract class LocaleStore {
  /// The stored language code ('de', 'en', …) or null for "system default".
  Future<String?> read();

  /// Persists [languageCode]; null removes the override.
  Future<void> write(String? languageCode);
}

class PrefsLocaleStore implements LocaleStore {
  static const _key = 'locale_override';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String? languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    if (languageCode == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, languageCode);
    }
  }
}

@Riverpod(keepAlive: true)
LocaleStore localeStore(Ref ref) => PrefsLocaleStore();

/// The user's language override; null means "follow the system locale".
/// Feeding this into `MaterialApp.locale` applies a change instantly,
/// no restart needed.
@Riverpod(keepAlive: true)
class LocaleController extends _$LocaleController {
  @override
  Future<Locale?> build() async {
    final code = await ref.watch(localeStoreProvider).read();
    return code == null ? null : Locale(code);
  }

  Future<void> set(Locale? locale) async {
    state = AsyncData(locale);
    await ref.read(localeStoreProvider).write(locale?.languageCode);
  }
}
