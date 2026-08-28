// SPDX-License-Identifier: 0BSD
import 'package:timezone/timezone.dart' as tz;

/// The IANA zones an owner may pick for a workspace (#711).
///
/// FROM THE DATABASE THE APP ALREADY SHIPS, not a hand-typed list: the
/// `timezone` package carries every zone `WorkspaceTime` can install,
/// so a name offered here is a name the clock will honour. The old form
/// was a free-text field — `Europe/Pairs` saved fine and every booking
/// window silently fell back to the device clock.
///
/// Filtered to the canonical `Region/City` names people recognise;
/// aliases (`CET`, `EST5EDT`, `Etc/GMT+3`) and legacy links are noise
/// in a picker and stay out.
abstract final class TimeZones {
  static const _regions = {
    'Africa', 'America', 'Antarctica', 'Asia', 'Atlantic', 'Australia',
    'Europe', 'Indian', 'Pacific',
  };

  /// Every pickable zone name, sorted.
  static List<String> get all {
    final names = tz.timeZoneDatabase.locations.keys
        .where((n) => _regions.contains(n.split('/').first))
        .toList()
      ..sort();
    return names;
  }

  /// Names matching [query] (case-insensitive, on any part — `paris`,
  /// `europe/`, `york`), or all of them for an empty query.
  static List<String> search(String query) {
    final q = query.trim().toLowerCase().replaceAll(' ', '_');
    if (q.isEmpty) return all;
    return all.where((n) => n.toLowerCase().contains(q)).toList();
  }

  /// Whether the clock can install [name].
  static bool isKnown(String name) => tz.timeZoneDatabase.locations.containsKey(name);

  /// `UTC+02:00` for [name] at [instant] — the one fact a picker row
  /// needs beside the name, because "Europe/Paris" means nothing to
  /// someone who only knows they are an hour behind.
  static String offsetLabel(String name, DateTime instant) {
    if (!isKnown(name)) return '';
    final offset = tz.TZDateTime.from(instant, tz.getLocation(name)).timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final h = offset.inHours.abs().toString().padLeft(2, '0');
    final m = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return 'UTC$sign$h:$m';
  }
}
