// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'help_hint_store.g.dart';

/// Per-device persistence for dismissed contextual help hints (#606):
/// one string-set under a single key, mirroring the notification-filter
/// seam — widget tests swap in the in-memory store.
abstract class HelpHintStore {
  Future<Set<String>> readDismissed();
  Future<void> writeDismissed(Set<String> ids);
}

class PrefsHelpHintStore implements HelpHintStore {
  const PrefsHelpHintStore();

  static const _key = 'dismissed_help_hints';

  @override
  Future<Set<String>> readDismissed() async =>
      ((await SharedPreferences.getInstance()).getStringList(_key) ??
              const <String>[])
          .toSet();

  @override
  Future<void> writeDismissed(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    if (ids.isEmpty) {
      // Empty = the fresh-install state; keep the prefs file clean.
      await prefs.remove(_key);
    } else {
      await prefs.setStringList(_key, ids.toList()..sort());
    }
  }
}

/// Test double — also handy for platforms without SharedPreferences.
class InMemoryHelpHintStore implements HelpHintStore {
  Set<String> dismissed = <String>{};

  @override
  Future<Set<String>> readDismissed() async => Set.of(dismissed);

  @override
  Future<void> writeDismissed(Set<String> ids) async =>
      dismissed = Set.of(ids);
}

@Riverpod(keepAlive: true)
HelpHintStore helpHintStore(Ref ref) => const PrefsHelpHintStore();
