// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'help_hint_store.g.dart';

/// Per-device persistence for the contextual help hints (#606, #610):
/// the dismissed-hint set and, since the tips became carousels (#610),
/// the last-shown tip index per surface — one string-set / string-list
/// key each, mirroring the notification-filter seam — widget tests swap
/// in the in-memory store.
abstract class HelpHintStore {
  Future<Set<String>> readDismissed();
  Future<void> writeDismissed(Set<String> ids);

  /// The last-shown tip index per hint id (#610). Unknown ids and
  /// out-of-range indices are the CALLER's problem by design — the
  /// carousel clamps with a modulo, so a shrunken tip list never breaks
  /// a device that stored a higher index.
  Future<Map<String, int>> readPositions();
  Future<void> writePositions(Map<String, int> positions);
}

class PrefsHelpHintStore implements HelpHintStore {
  const PrefsHelpHintStore();

  static const _key = 'dismissed_help_hints';
  static const _positionsKey = 'help_hint_positions';

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

  @override
  Future<Map<String, int>> readPositions() async {
    final raw =
        (await SharedPreferences.getInstance()).getStringList(_positionsKey) ??
        const <String>[];
    final positions = <String, int>{};
    for (final entry in raw) {
      // "id:index" — a malformed entry (hand-edited prefs, an old
      // format) is simply skipped: the carousel then starts at tip 1.
      final sep = entry.lastIndexOf(':');
      if (sep <= 0) continue;
      final index = int.tryParse(entry.substring(sep + 1));
      if (index == null) continue;
      positions[entry.substring(0, sep)] = index;
    }
    return positions;
  }

  @override
  Future<void> writePositions(Map<String, int> positions) async {
    final prefs = await SharedPreferences.getInstance();
    if (positions.isEmpty) {
      await prefs.remove(_positionsKey);
    } else {
      final entries =
          positions.entries.map((e) => '${e.key}:${e.value}').toList()..sort();
      await prefs.setStringList(_positionsKey, entries);
    }
  }
}

/// Test double — also handy for platforms without SharedPreferences.
class InMemoryHelpHintStore implements HelpHintStore {
  Set<String> dismissed = <String>{};
  Map<String, int> positions = <String, int>{};

  @override
  Future<Set<String>> readDismissed() async => Set.of(dismissed);

  @override
  Future<void> writeDismissed(Set<String> ids) async => dismissed = Set.of(ids);

  @override
  Future<Map<String, int>> readPositions() async => Map.of(positions);

  @override
  Future<void> writePositions(Map<String, int> next) async =>
      positions = Map.of(next);
}

@Riverpod(keepAlive: true)
HelpHintStore helpHintStore(Ref ref) => const PrefsHelpHintStore();
