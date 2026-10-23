// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import '../../../core/storage/prefs_stores.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/saved_place.dart';

/// The saved places in the device's preferences: one JSON list under
/// `saved_places.<namespace>`. Nothing here reaches a server.
class PrefsSavedPlacesStore implements SavedPlacesStore {
  const PrefsSavedPlacesStore();

  static const _prefix = 'saved_places.';

  PrefsStringStore _of(String namespace) =>
      PrefsStringStore('$_prefix$namespace');

  @override
  Future<List<SavedPlace>> read(String namespace) async {
    final raw = await _of(namespace).read();
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('not a list');
      return [for (final item in decoded) SavedPlace.fromJson(item)];
    } on FormatException catch (e, st) {
      // An unreadable entry is treated as empty rather than hiding every
      // saved place behind an error; the next write replaces it.
      TraceLogger.instance.warn(
        'directory',
        'saved places unreadable, starting empty',
        error: e,
        stackTrace: st,
      );
      return const [];
    }
  }

  @override
  Future<void> write(String namespace, List<SavedPlace> places) => _of(
        namespace,
      ).write(
        places.isEmpty
            ? null
            : jsonEncode([for (final p in places) p.toJson()]),
      );
}
