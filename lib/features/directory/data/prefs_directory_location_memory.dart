// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import '../../../core/storage/prefs_stores.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/directory_location.dart';
import '../domain/directory_location_memory.dart';

/// The found addresses in the device's preferences: one JSON object under
/// `directory_locations`, each address to `[latitude, longitude, label]`,
/// oldest first. Nothing here reaches a server.
class PrefsDirectoryLocationMemory implements DirectoryLocationMemory {
  const PrefsDirectoryLocationMemory();

  static const _store = PrefsStringStore('directory_locations');

  @override
  Future<Map<String, DirectoryLocation>> read() async {
    final raw = await _store.read();
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('not an object');
      }
      final found = <String, DirectoryLocation>{};
      for (final MapEntry(:key, :value) in decoded.entries) {
        if (value is! List || value.length != 3) continue;
        final location = DirectoryLocation.parse(
          value[0],
          value[1],
          label: '${value[2]}',
        );
        if (location != null) found[key] = location;
      }
      return found;
    } on FormatException catch (e, st) {
      // An unreadable entry reads as nothing remembered: the places are
      // looked up again, and the next answer replaces it.
      TraceLogger.instance.warn(
        'directory',
        'remembered map places unreadable, starting empty',
        error: e,
        stackTrace: st,
      );
      return {};
    }
  }

  @override
  Future<void> write(Map<String, DirectoryLocation> locations) => _store.write(
    locations.isEmpty
        ? null
        : jsonEncode({
            for (final MapEntry(:key, :value) in locations.entries)
              key: [value.latitude, value.longitude, value.label],
          }),
  );
}
