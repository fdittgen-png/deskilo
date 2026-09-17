// SPDX-License-Identifier: 0BSD
import 'package:flutter/foundation.dart';

/// #1305 S3 — which reads are being answered from the cache's STALE tier
/// right now, and since when that answer was saved.
///
/// `cachedFetch` falls back to a stale entry when the network fails, which
/// is the right call offline: a plan from ten minutes ago beats a blank
/// screen. But availability served that way looks exactly like live
/// availability, and a seat drawn free may have been taken since. A screen
/// that renders availability listens here and says so.
///
/// One process-wide instance, like `TraceLogger`: the cache is the only
/// writer, and a key leaves the moment a fetch for it succeeds.
class StaleReads extends ChangeNotifier {
  StaleReads();

  static final StaleReads instance = StaleReads();

  final Map<String, DateTime> _savedAt = {};

  /// [key] was just answered from a cache entry saved at [savedAt].
  void served(String key, DateTime savedAt) {
    if (_savedAt[key] == savedAt) return;
    _savedAt[key] = savedAt;
    notifyListeners();
  }

  /// [key] was just fetched from the network — so the network is back for
  /// its whole family (`resv:`, `plan:` — the part before the first `:`).
  /// The other stale answers of that family are dropped with it: a screen
  /// refetches what it shows, and a mark left on a date nobody is looking
  /// at would keep saying "offline" while everything on screen is live.
  void fresh(String key) {
    final family = key.contains(':') ? key.substring(0, key.indexOf(':') + 1) : key;
    final before = _savedAt.length;
    _savedAt.removeWhere((k, _) => k == key || k.startsWith(family));
    if (_savedAt.length != before) notifyListeners();
  }

  /// When the OLDEST stale answer among keys starting with any of
  /// [prefixes] was saved, or null when all of them are live.
  DateTime? oldestSavedAt(Iterable<String> prefixes) {
    DateTime? oldest;
    for (final e in _savedAt.entries) {
      if (!prefixes.any(e.key.startsWith)) continue;
      if (oldest == null || e.value.isBefore(oldest)) oldest = e.value;
    }
    return oldest;
  }

  @visibleForTesting
  void reset() {
    if (_savedAt.isEmpty) return;
    _savedAt.clear();
    notifyListeners();
  }
}
