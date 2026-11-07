// SPDX-License-Identifier: AGPL-3.0-or-later

/// Fixed-shape date and time text for files and identifiers (#2385).
///
/// Every formatter reads the fields of the [DateTime] it is given and
/// converts nothing: pass a wall date (`WorkspaceTime.dateOf`, or a
/// value already in the zone the file is written in). Text a person
/// reads on a screen goes through `DateFormat` with the locale instead.
/// This file is the one place that pads a date component by hand.
library;

/// [n] with at least two digits: `7` → `07`.
String twoDigits(int n) => n.toString().padLeft(2, '0');

/// A year as ISO 8601 writes it: four digits.
String _year(int year) => year.toString().padLeft(4, '0');

/// `20260304`, or `2026-03-04` with `separator: '-'`.
String ymd(DateTime d, {String separator = ''}) =>
    '${_year(d.year)}$separator${twoDigits(d.month)}$separator${twoDigits(d.day)}';

/// `2026-03-04` — ISO 8601 calendar date.
String isoDay(DateTime d) => ymd(d, separator: '-');

/// `04/03/2026` — day first, as the British and French formats read it.
String dmy(DateTime d, {String separator = '/'}) =>
    '${twoDigits(d.day)}$separator${twoDigits(d.month)}$separator${_year(d.year)}';

/// `0403` — DATEV's Belegdatum: day and month, the year is the header's.
String ddmm(DateTime d) => '${twoDigits(d.day)}${twoDigits(d.month)}';

/// `2026-03`, or `202603` with `separator: ''`.
String yearMonth(int year, int month, {String separator = '-'}) =>
    '${_year(year)}$separator${twoDigits(month)}';

/// `09:05`, or `0905` with `separator: ''`.
String hhmm(DateTime d, {String separator = ':'}) =>
    '${twoDigits(d.hour)}$separator${twoDigits(d.minute)}';

/// `09:05:03`, or `090503` with `separator: ''`.
String hhmmss(DateTime d, {String separator = ':'}) =>
    '${hhmm(d, separator: separator)}$separator${twoDigits(d.second)}';

/// Minutes after midnight as a clock: `545` → `09:05`.
String clockFromMinutes(int minutes) =>
    '${twoDigits(minutes ~/ 60)}:${twoDigits(minutes % 60)}';
