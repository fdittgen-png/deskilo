// SPDX-License-Identifier: 0BSD
import 'package:shared_preferences/shared_preferences.dart';

/// Shared SharedPreferences bases (maintainability audit: six pref
/// seams repeated the same getInstance / get / remove-on-null / set
/// shape). Each feature keeps its ABSTRACT seam — widget tests keep
/// their in-memory fakes — only the production impls collapse here.
class PrefsStringStore {
  const PrefsStringStore(this.key);

  final String key;

  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);

  /// Null clears the preference (the "follow the default" state every
  /// string seam shares).
  Future<void> write(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }
}

class PrefsBoolStore {
  const PrefsBoolStore(this.key, {this.fallback = false});

  final String key;

  /// Value reported while the preference was never written.
  final bool fallback;

  Future<bool> read() async =>
      (await SharedPreferences.getInstance()).getBool(key) ?? fallback;

  Future<void> write(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(key, value);
}
