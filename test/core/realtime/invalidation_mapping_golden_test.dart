// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — the table -> providers mapping, frozen as it is (unverified as to
// intent: it records what the map does). Every table the sync layer can
// emit, with the providers it invalidates and whether it busts the plan
// cache. Moving the map to where the features are composed must leave this
// file unchanged. Rewrite deliberately with UPDATE_INVALIDATION_MAP=1.
import 'dart:io';

import 'package:deskilo/app/realtime_invalidations.dart';
import 'package:deskilo/core/realtime/invalidation_map.dart';
import 'package:flutter_test/flutter_test.dart';

const _golden = 'test/core/realtime/fixtures/invalidation_map.golden';

const _extraTables = [
  'offices',
  'desks',
  'seats',
  'plan_images',
  'event_decisions',
  'payment_intents',
  'quota_extensions',
  'seat_accessories',
  kProfilePresenceSignal,
  'no_such_table',
];

void main() {
  test('every table maps to the providers it always did', () {
    final lines = <String>[];
    for (final table in {...mappedTables, ..._extraTables}.toList()..sort()) {
      final entry = invalidationFor(table);
      final names = [for (final p in entry.providers) '${p.name ?? p}']..sort();
      lines.add(
        '$table bustsPlanCache=${entry.bustsPlanCache} ${names.join(', ')}',
      );
    }
    final text = '${lines.join('\n')}\n';
    if (Platform.environment['UPDATE_INVALIDATION_MAP'] == '1') {
      File(_golden).writeAsStringSync(text);
      return;
    }
    expect(text, File(_golden).readAsStringSync());
  });
}
