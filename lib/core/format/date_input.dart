// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The one reader of a date a person types. A typed date and a picked date
// pass the same check and give the same calendar date (a local midnight,
// as the date picker returns it), never a device timestamp.
//
// The rules:
//   * the day, month and year come in the order of the person's format
//     locale (`DateFormat.yMd`): day first in de_DE, en_GB and fr_FR, month
//     first in en_US, year first in ja_JP;
//   * the parts are separated by `.`, `/`, `-` or spaces, or not at all:
//     then exactly eight digits, two for the day, two for the month and
//     four for the year;
//   * the year always has four digits; a two-digit year is refused, never
//     completed with a century;
//   * a date that does not exist (31 February, month 13) is refused, never
//     rolled over into the next month;
//   * outside [first]..[last] when the caller gives them: refused.
import 'package:intl/intl.dart';

/// Why a typed date was refused.
enum DateInputProblem { malformed, twoDigitYear, impossible, outOfRange }

/// What a typed date reads as: a [date], or a [problem], or neither when
/// nothing was typed (the caller says what blank means).
typedef DateRead = ({DateTime? date, DateInputProblem? problem});

final _separated = RegExp(r'^[0-9]+([./\- ]+[0-9]+){2}\.?$');
final _digits = RegExp(r'^[0-9]+$');

/// The order of the day (`d`), month (`M`) and year (`y`) in [locale]'s
/// numeric date, e.g. `dMy` for de_DE, `Mdy` for en_US.
String _order(String locale) {
  final pattern = DateFormat.yMd(locale).pattern ?? 'd/M/y';
  final unquoted = pattern.replaceAll(RegExp("'[^']*'"), '');
  final order = StringBuffer();
  for (final c in unquoted.split('')) {
    if ('dMy'.contains(c) && !order.toString().contains(c)) order.write(c);
  }
  return order.length == 3 ? order.toString() : 'dMy';
}

/// The date typed in [raw] under [locale]'s order.
DateRead readDateInput(
  String raw, {
  required String locale,
  DateTime? first,
  DateTime? last,
}) {
  final text = raw.trim();
  if (text.isEmpty) return (date: null, problem: null);
  final parts = _parts(text, _order(locale));
  if (parts == null) {
    return (date: null, problem: _shapeProblem(text));
  }
  if (parts.y.length != 4) {
    final short = parts.y.length <= 2;
    return (
      date: null,
      problem: short
          ? DateInputProblem.twoDigitYear
          : DateInputProblem.malformed,
    );
  }
  final y = int.parse(parts.y), m = int.parse(parts.m), d = int.parse(parts.d);
  final probe = DateTime.utc(y, m, d);
  if (m < 1 || m > 12 || d < 1 || probe.month != m || probe.day != d) {
    return (date: null, problem: DateInputProblem.impossible);
  }
  final date = DateTime(y, m, d);
  if ((first != null && date.isBefore(_day(first))) ||
      (last != null && date.isAfter(_day(last)))) {
    return (date: null, problem: DateInputProblem.outOfRange);
  }
  return (date: date, problem: null);
}

/// [date] as the field writes it back: [locale]'s numeric date with a
/// four-digit year (`1.2.2030`, `01/02/2030`, `2/1/2030`).
String formatDateInput(DateTime date, {required String locale}) =>
    DateFormat.yMd(locale).format(_day(date));

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

/// Six digits without separators is a two-digit year; anything else that
/// is not a date shape is malformed.
DateInputProblem _shapeProblem(String text) =>
    _digits.hasMatch(text) && text.length == 6
    ? DateInputProblem.twoDigitYear
    : DateInputProblem.malformed;

({String d, String m, String y})? _parts(String text, String order) {
  List<String> fields;
  if (_digits.hasMatch(text)) {
    if (text.length != 8) return null;
    fields = _splitEight(text, order);
  } else if (_separated.hasMatch(text)) {
    fields = text
        .split(RegExp(r'[./\- ]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (fields.length != 3) return null;
  } else {
    return null;
  }
  String at(String c) => fields[order.indexOf(c)];
  final d = at('d'), m = at('M'), y = at('y');
  if (d.length > 2 || m.length > 2) return null;
  return (d: d, m: m, y: y);
}

/// Eight digits cut in [order]: two for the day and the month, four for
/// the year.
List<String> _splitEight(String text, String order) {
  final out = <String>[];
  var at = 0;
  for (final c in order.split('')) {
    final width = c == 'y' ? 4 : 2;
    out.add(text.substring(at, at + width));
    at += width;
  }
  return out;
}
