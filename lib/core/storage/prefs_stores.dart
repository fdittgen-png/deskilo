// SPDX-License-Identifier: AGPL-3.0-or-later
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
