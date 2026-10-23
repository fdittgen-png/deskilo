// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import '../../../core/storage/prefs_stores.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/discovery_view.dart';

/// The discovery view preference in the device's preferences, one JSON
/// object under `discovery_view.<namespace>`. Nothing here reaches a
/// server.
class PrefsDiscoveryViewStore implements DiscoveryViewStore {
  const PrefsDiscoveryViewStore();

  static const _prefix = 'discovery_view.';

  PrefsStringStore _of(String namespace) =>
      PrefsStringStore('$_prefix$namespace');

  @override
  Future<DiscoveryViewPreference?> read(String namespace) async {
    final raw = await _of(namespace).read();
    if (raw == null) return null;
    try {
      return DiscoveryViewPreference.fromJson(jsonDecode(raw));
    } on Exception catch (e, st) {
      // An unreadable entry (not JSON, or not this shape) reads as no choice: the list, and the map
      // asks again before it loads.
      TraceLogger.instance.warn(
        'directory',
        'discovery view preference unreadable, starting from the list',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  @override
  Future<void> write(String namespace, DiscoveryViewPreference preference) =>
      _of(namespace).write(jsonEncode(preference.toJson()));
}
