// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4307 -- a database test of a quote or a standalone invoice never builds a date
// from the database clock's own `current_date`: the server compares a decision, a
// validity and an issue date with the BUSINESS's local day, which is another day
// during the first (or last) hours of every night, so such a test gave a different
// verdict at 23:30 UTC than at noon. The day comes from the business's time zone,
// through the file's one helper (`pg_temp.today()`, the server's own
// `workspace_today`).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The files that date a quote or a standalone invoice.
final _family = RegExp(r'(quote|standalone|billing_customers|invoice_approval)');

/// Where a bare `current_date` appears outside a comment, as `file:line`.
List<String> bareCurrentDates(String name, String text) => [
  for (final (i, line) in text.split('\n').indexed)
    if (!line.trimLeft().startsWith('--') && RegExp(r'\bcurrent_date\b').hasMatch(line.split('--').first))
      '$name:${i + 1}',
];

void main() {
  test('a bare current_date in a quote or invoice test is found, a comment and the helper are not', () {
    const planted = '''
-- the day is pg_temp.today(), never current_date
select is(x, current_date, 'bad');
select is(x, pg_temp.today(), 'good');
''';
    expect(bareCurrentDates('planted.sql', planted), ['planted.sql:2']);
  });

  test('the quote and standalone invoice pgTAP files take the business day, not the clock\'s', () {
    final files = Directory('supabase/tests/database')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql') && _family.hasMatch(f.uri.pathSegments.last))
        .toList();
    expect(files, isNotEmpty);
    final found = [
      for (final f in files) ...bareCurrentDates(f.uri.pathSegments.last, f.readAsStringSync()),
    ];
    expect(
      found,
      isEmpty,
      reason: 'use pg_temp.today() (workspace_today of the business): a bare current_date is the UTC date',
    );
  });
}
