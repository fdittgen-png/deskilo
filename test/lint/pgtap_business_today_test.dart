// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4307, #4384 -- a database test never builds a business date from the database
// clock's own `current_date` (or `now()::date`): the server compares a decision, a
// validity, an issue or an as-of date with the BUSINESS's local day, which is another
// day during the first (or last) hours of every night, so such a test gave a different
// verdict at 23:30 UTC than at noon (494 on 22 Nov 2026). The day comes from the
// business's time zone, through `public.workspace_today(<workspace>)` (a file keeps it
// in one `pg_temp.today()` helper or a `set_config`).
//
// A date that truly is the UTC date (a global reference row, a window wide enough to
// hold both days, the day of `now()` stamped by the database itself) says so, with a
// reason, on the line or the line above:
//
//   -- utc-date: <why the database's own date is the right one here>
//
// or once for the whole file, in its first 40 lines:
//
//   -- utc-date-file: <why every date of this file is the database's own>
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

final _clockDate = RegExp(
  r'\b(current_date|(now\(\)|current_timestamp|localtimestamp)\s*::\s*date)\b',
);
final _lineReason = RegExp(r'--\s*utc-date:\s*\S.{6,}');
final _fileReason = RegExp(r'--\s*utc-date-file:\s*\S.{6,}');

/// Where a database-clock date appears outside a comment and without a stated
/// reason, as `file:line`.
List<String> clockDates(String name, String text) {
  final lines = text.split('\n');
  if (lines.take(40).any(_fileReason.hasMatch)) return const [];
  return [
    for (final (i, line) in lines.indexed)
      if (_clockDate.hasMatch(line.split('--').first) &&
          !_lineReason.hasMatch(line) &&
          !(i > 0 && _lineReason.hasMatch(lines[i - 1])))
        '$name:${i + 1}',
  ];
}

void main() {
  test('a bare clock date is found; a comment, the helper and a stated reason are not', () {
    const planted = '''
-- the day is pg_temp.today(), never current_date
select is(x, current_date, 'bad');
select is(x, pg_temp.today(), 'good');
select is(y, now()::date, 'bad as well');
select is(z, current_date, 'ok'); -- utc-date: a global reference row, no business
-- utc-date: the window below holds both days
select is(w, current_date - 1, 'ok');
select is(v, current_date, 'a reason too short follows'); -- utc-date: no
''';
    expect(clockDates('planted.sql', planted), [
      'planted.sql:2',
      'planted.sql:4',
      'planted.sql:8',
    ]);
  });

  test('a file-level reason covers the whole file', () {
    const planted = '''
-- utc-date-file: every date here is a global tax reference row
select is(x, current_date, 'ok');
''';
    expect(clockDates('planted.sql', planted), isEmpty);
  });

  test('the database tests take the business day, or say why the database\'s own is right', () {
    final found = [
      for (final f in sqlFiles('supabase/tests/database'))
        ...clockDates(f.uri.pathSegments.last, f.readAsStringSync()),
    ];
    expect(
      found,
      isEmpty,
      reason:
          'use public.workspace_today(<workspace>) (the business\'s day), or state "-- utc-date: <reason>" '
          'on the line or the line above: a bare current_date is the UTC date',
    );
  });
}
