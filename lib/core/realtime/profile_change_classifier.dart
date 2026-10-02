// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2019 C — a profile row changes every few minutes per person for one
// reason: the presence heartbeat (`touch_last_seen`, 0028). Each of those
// used to refetch every profile, every name and the default-workspace
// choice. An UPDATE whose row differs from the last one seen ONLY in
// presence or system columns is now a presence signal, which refreshes
// the presence consumer alone.
//
// The evidence is the client's own: under RLS a Realtime UPDATE carries
// only the old row's key, so the new row is compared with the previous
// new row of the same id. No previous row (first sighting, after a
// delete), an insert, a delete or a row without an id is a full
// `profiles` signal — unknown stays conservatively fresh, so a name,
// privacy or default-workspace change is never mistaken for presence.
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/system_columns.dart';
import 'invalidation_map.dart' show kProfilePresenceSignal;

class ProfileChangeClassifier {
  /// Columns whose change alone is presence, not identity.
  static const presenceColumns = {'last_seen_at'};

  final _fingerprints = <String, String>{};

  /// `profiles` or [kProfilePresenceSignal] for one change.
  String signal(PostgresChangeEvent event, Map<String, dynamic> newRecord) {
    final id = newRecord['id'];
    if (event == PostgresChangeEvent.delete || id is! String) {
      if (id is String) _fingerprints.remove(id);
      return 'profiles';
    }
    final fingerprint = _fingerprint(newRecord);
    final previous = _fingerprints[id];
    _fingerprints[id] = fingerprint;
    return event == PostgresChangeEvent.update && previous == fingerprint
        ? kProfilePresenceSignal
        : 'profiles';
  }

  static String _fingerprint(Map<String, dynamic> row) {
    final keys =
        row.keys
            .where(
              (k) =>
                  !presenceColumns.contains(k) &&
                  !SystemColumns.keys.contains(k),
            )
            .toList()
          ..sort();
    return jsonEncode([
      for (final k in keys) [k, row[k]],
    ]);
  }
}
