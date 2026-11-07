// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3332 -- the date spellings the country packages share
// (`deskilo_jurisdiction_standards`) are the application's own
// (`lib/core/time/date_text.dart`) for every instant and separator the filing
// files use: the two cannot drift apart without this failing.
import 'package:deskilo/core/time/date_text.dart' as core;
import 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart'
    as api;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final instants = <DateTime>[
    DateTime.utc(2026, 3, 4, 9, 5),
    DateTime.utc(2026, 12, 31, 23, 59),
    DateTime.utc(2024, 2, 29),
    DateTime.utc(7, 1, 2),
    DateTime(2026, 10, 2),
    DateTime(1999, 1, 1, 12, 30),
  ];

  test('ymd, hhmm and twoDigits equal the application\'s', () {
    for (final d in instants) {
      for (final sep in ['', '-', '/', '.']) {
        expect(
          api.ymd(d, separator: sep),
          core.ymd(d, separator: sep),
          reason: '$d "$sep"',
        );
      }
      for (final sep in [':', '', 'h']) {
        expect(
          api.hhmm(d, separator: sep),
          core.hhmm(d, separator: sep),
          reason: '$d "$sep"',
        );
      }
    }
    for (final d in instants) {
      for (final sep in [':', '', '.']) {
        expect(api.hhmmss(d, separator: sep), core.hhmmss(d, separator: sep),
            reason: '$d "$sep"');
      }
    }
    for (var n = 0; n < 120; n++) {
      expect(api.twoDigits(n), core.twoDigits(n));
    }
  });
}
