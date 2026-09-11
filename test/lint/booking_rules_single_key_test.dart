// SPDX-License-Identifier: 0BSD
//
// #1147 / #1089 — booking_rules is one jsonb column and it is written ONE
// key at a time, merged in the database (set_booking_rule, 0195). A
// client that SELECTs the object, merges in Dart and UPDATEs it back
// puts a stale snapshot over whatever another screen saved in between.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  test('no client writes the whole booking_rules object', () {
    final hits = scanLines(
      handWrittenDartFiles('lib'),
      (line) => line.contains("'booking_rules': rules") ||
          line.contains("update({'booking_rules'"),
    );
    expect(hits, isEmpty,
        reason: 'merge one key with _mergeBookingRule / set_booking_rule:'
            '\n${hits.join('\n')}');
  });
}
