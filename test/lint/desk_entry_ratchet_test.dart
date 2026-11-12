// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A date is typed or picked, and an amount accepts only an amount: the
// form kit's `AppDateField` (lib/core/ui/date_field.dart) and
// `AppAmountField` (lib/core/ui/amount_field.dart). What has not moved to
// them yet is counted here, and each count may only FALL:
//
//   * a picker-only date: a `showAppDatePicker(` call outside the date field,
//     where a desktop keyboard cannot type the date;
//   * a numeric keyboard (`TextInputType.number…`) whose field names no
//     input formatter, so every character a desktop keyboard sends is
//     accepted; the amount field brings its own and is not counted.
//
// A change that lowers a count lowers its ceiling in the same commit (the
// failure prints the number), so the ground taken is kept.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Measured after the money module's dates and amounts moved (#3612).
const int _pickerOnlyDateCeiling = 10;
const int _numericWithoutFormatterCeiling = 78;

const _dateField = 'lib/core/ui/date_field.dart';
const _amountField = 'lib/core/ui/amount_field.dart';

/// How far around a keyboard type the field's formatter may stand.
const _fieldWindow = 10;

final _picker = RegExp(r'\bshowAppDatePicker\(');

/// The entry point itself defines the call it is counted by.
const _pickerEntryPoint = 'lib/core/ui/app_date_picker.dart';
final _numericKeyboard = RegExp(
  r'TextInputType\.(number\b|numberWithOptions\()',
);

List<File> _lib(String except) =>
    handWrittenDartFiles('lib').where((f) => f.path != except).toList();

/// The lines of [file] that are code, comment lines blanked so the line
/// numbers stay.
List<String> _code(File file) => [
  for (final line in file.readAsLinesSync())
    if (line.trimLeft().startsWith('//')) '' else line,
];

int _pickerOnlyDates() {
  var n = 0;
  for (final f in _lib(_dateField)) {
    if (f.path == _pickerEntryPoint) continue;
    for (final line in _code(f)) {
      n += _picker.allMatches(line).length;
    }
  }
  return n;
}

int _numericWithoutFormatter() {
  var n = 0;
  for (final f in _lib(_amountField)) {
    final lines = _code(f);
    for (var i = 0; i < lines.length; i++) {
      if (!_numericKeyboard.hasMatch(lines[i])) continue;
      final from = (i - _fieldWindow).clamp(0, lines.length);
      final to = (i + _fieldWindow).clamp(0, lines.length);
      if (!lines.sublist(from, to).join('\n').contains('inputFormatters')) {
        n++;
      }
    }
  }
  return n;
}

void _ratchet(String what, int count, int ceiling, String use) {
  expect(
    count,
    lessThanOrEqualTo(ceiling),
    reason: '$what grew to $count (ceiling $ceiling). Use $use instead.',
  );
  expect(
    count,
    ceiling,
    reason:
        '$what fell to $count — lower the ceiling to $count in this '
        'commit, so the next change cannot win the ground back.',
  );
}

void main() {
  test('picker-only date fields only ever decrease', () {
    _ratchet(
      'showAppDatePicker outside AppDateField',
      _pickerOnlyDates(),
      _pickerOnlyDateCeiling,
      'AppDateField (lib/core/ui/date_field.dart)',
    );
  });

  test('numeric fields without a formatter only ever decrease', () {
    _ratchet(
      'A numeric keyboard without an input formatter',
      _numericWithoutFormatter(),
      _numericWithoutFormatterCeiling,
      'AppAmountField (lib/core/ui/amount_field.dart) for an amount, or '
          'an input formatter',
    );
  });

  test('the two fields themselves are what the counts point to', () {
    expect(File(_dateField).readAsStringSync(), contains('showAppDatePicker('));
    expect(File(_amountField).readAsStringSync(), contains('inputFormatters'));
  });
}
