// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2385 — one implementation each for money, date, CSV-cell and percent
// text, in lib/core. The same small helpers had been written again in
// file after file (22 `money()`, 4 `q()`, 5 `_percent()`, a dozen date
// formatters), each with its own edge cases, and only one of the CSV
// writers guarded against formula injection. These checks fail on a
// reintroduction:
//
// - money: `minorToText` (files) or `formatMinor` (screens);
// - CSV cells: `csvCell` (lib/core/text/csv.dart);
// - rates: `percentText` (lib/core/text/number_text.dart);
// - dates: lib/core/time/date_text.dart, the one place a date component
//   is padded by hand.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  final outsideCore = handWrittenDartFiles('lib')
      .where((f) => !f.path.startsWith('lib/core/'))
      .toList();

  test('no local money(), q() or _percent() outside lib/core', () {
    final local = RegExp(
      r'^(static\s+)?String\s+(money|_money|q|_q|_percent)\s*\(',
    );
    final hits = scanLines(outsideCore, local.hasMatch);
    expect(
      hits,
      isEmpty,
      reason:
          'use minorToText / formatMinor, csvCell or percentText '
          '(lib/core):\n${hits.join('\n')}',
    );
  });

  test('no money divided by a literal 100 and printed', () {
    final hits = scanLines(
      handWrittenDartFiles('lib'),
      (line) => RegExp(r'/ 100(\.0)?\)\.toStringAsFixed').hasMatch(line),
    );
    expect(
      hits,
      isEmpty,
      reason:
          'use minorToText (lib/core/money/money_text.dart): a yen '
          'has no cents\n${hits.join('\n')}',
    );
  });

  test('date components are padded in date_text.dart only', () {
    final padding = RegExp(
      r"\.(day|month|hour|minute|second)\)?\.toString\(\)\.padLeft\(2, '0'\)",
    );
    final hits = scanLines(
      handWrittenDartFiles('lib')
          .where((f) => f.path != 'lib/core/time/date_text.dart'),
      padding.hasMatch,
    );
    expect(
      hits,
      isEmpty,
      reason:
          'use ymd / isoDay / yearMonth / hhmm / twoDigits '
          '(lib/core/time/date_text.dart):\n${hits.join('\n')}',
    );
  });
}
