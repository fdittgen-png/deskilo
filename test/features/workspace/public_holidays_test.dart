// SPDX-License-Identifier: 0BSD
//
// #1274 — the client reads the server's answer and never recomputes it.
//
// The generator is SQL, because `apply_workspace_template` runs in the
// database. So the only thing this layer can get wrong is the reading:
// a missed `locked` flag would let the UI offer to create a day in a
// month that is already invoiced, which is the one thing the feature
// must never do.
import 'package:deskilo/features/workspace/domain/public_holidays.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it reads the days, the flags and the count', () {
    final g = holidayGenerationFromJson(const {
      'days': [
        {'day': '2026-01-01', 'key': 'newYear', 'locked': false, 'present': false},
        {'day': '2026-07-14', 'key': 'nationalDay', 'locked': true, 'present': false},
        {'day': '2026-12-25', 'key': 'christmas', 'locked': false, 'present': true},
      ],
      'locked_months': ['2026-07'],
      'created': 1,
    });

    expect(g.days, hasLength(3));
    expect(g.days.first.day, DateTime(2026, 1, 1));
    expect(g.days.first.key, 'newYear');
    expect(g.lockedMonths, ['2026-07']);
    expect(g.created, 1);
  });

  test('creatable excludes what is locked and what is already there', () {
    final g = holidayGenerationFromJson(const {
      'days': [
        {'day': '2026-01-01', 'key': 'newYear', 'locked': false, 'present': false},
        {'day': '2026-07-14', 'key': 'nationalDay', 'locked': true, 'present': false},
        {'day': '2026-12-25', 'key': 'christmas', 'locked': false, 'present': true},
      ],
      'locked_months': ['2026-07'],
      'created': 0,
    });

    expect(g.creatable.map((d) => d.key), ['newYear'],
        reason: 'an invoiced month and an existing day are both not '
            'offered — the first would change a bill, the second is a '
            'no-op the owner should not be asked to confirm');
  });

  test('an older client survives a newer server', () {
    final g = holidayGenerationFromJson(const {
      'days': [
        {
          'day': '2026-01-01',
          'key': 'newYear',
          'locked': false,
          'present': false,
          'regional': 'alsace-moselle',
        },
      ],
      'locked_months': <String>[],
      'created': 0,
      'something_added_later': true,
    });

    expect(g.days, hasLength(1));
    expect(g.days.single.key, 'newYear');
  });

  test('a malformed day is dropped rather than crashing the screen', () {
    final g = holidayGenerationFromJson(const {
      'days': [
        {'key': 'noDate'},
        {'day': '2026-01-01', 'key': 'newYear'},
      ],
      'created': 0,
    });

    expect(g.days.map((d) => d.key), ['newYear']);
    expect(g.lockedMonths, isEmpty);
  });

  test('created accepts the number however the driver typed it', () {
    expect(holidayGenerationFromJson(const {'created': 11}).created, 11);
    expect(holidayGenerationFromJson(const {'created': '11'}).created, 11);
    expect(holidayGenerationFromJson(const {}).created, 0);
  });
}
