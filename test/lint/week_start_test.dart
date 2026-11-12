// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3648 — the week starts where the reader's format locale starts it, and
// they may choose otherwise. Presentation does no weekday arithmetic of its
// own: the first day, a day's column and the header names come from
// `lib/core/i18n/week_start.dart`, and every date picker is opened through
// `lib/core/ui/app_date_picker.dart`, which carries the same week. These
// COUNT what must not come back; the counts are zero and only a stated
// exception raises one.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The one file that may call the framework's date pickers.
const _pickerEntryPoint = 'lib/core/ui/app_date_picker.dart';

final _frameworkPicker = RegExp(r'\bshow(?:DateRange|Date)Picker\(');

/// A Monday written into presentation: `weekday - 1` offsets and
/// `DateTime.monday`.
final _mondayArithmetic = RegExp(r'\.weekday\s*-\s*1\b|\bDateTime\.monday\b');

/// A weekday initial cut from a name: `substring(0, 1)` beside a weekday.
final _substringInitial = RegExp(r'weekday\w*\W.*\.substring\(0,\s*1\)', caseSensitive: false);

Iterable<File> _presentation() =>
    handWrittenDartFilesIn(['lib/features', 'lib/core/ui']);

List<String> _hits(RegExp pattern, {String? except}) {
  final found = <String>[];
  for (final f in _presentation()) {
    final path = f.path.replaceAll(r'\', '/');
    if (path == except) continue;
    final lines = File(f.path).readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trimLeft();
      if (line.startsWith('//')) continue;
      if (pattern.hasMatch(lines[i])) found.add('$path:${i + 1}');
    }
  }
  return found;
}

void main() {
  test('a date picker is opened only through showAppDatePicker', () {
    expect(
      _hits(_frameworkPicker, except: _pickerEntryPoint),
      isEmpty,
      reason: 'the framework picker takes its first column from the interface '
          'language; showAppDatePicker / showAppDateRangePicker carry the '
          "reader's week (#3648)",
    );
  });

  test('no Monday is hard-coded in presentation', () {
    expect(
      _hits(_mondayArithmetic),
      isEmpty,
      reason: 'use weekStartOf / startOfWeek / weekColumnOf '
          '(lib/core/i18n/week_start.dart): the week starts where the '
          "reader's locale, or their setting, starts it (#3648)",
    );
  });

  test('no weekday initial is cut from a name', () {
    expect(
      _hits(_substringInitial),
      isEmpty,
      reason: "use the locale's narrow names (weekdayHeaders, "
          'WeekdayHeaderRow): a first letter is not one code unit everywhere '
          'and two days share it (#3648)',
    );
  });
}
