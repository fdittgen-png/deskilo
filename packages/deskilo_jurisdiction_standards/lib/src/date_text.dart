// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The few date spellings the filing files share, written once for every
// country package. They are pinned to the application's own (`lib/core/time/
// date_text.dart`) by a test in the application, so the two cannot drift.

/// [n] with at least two digits: `7` -> `07`.
String twoDigits(int n) => n.toString().padLeft(2, '0');

String _year(int year) => year.toString().padLeft(4, '0');

/// `20260304`, or `2026-03-04` with `separator: '-'`.
String ymd(DateTime d, {String separator = ''}) =>
    '${_year(d.year)}$separator${twoDigits(d.month)}$separator${twoDigits(d.day)}';

/// `09:30`, or `0930` with `separator: ''`.
String hhmm(DateTime d, {String separator = ':'}) =>
    '${twoDigits(d.hour)}$separator${twoDigits(d.minute)}';

/// `09:30:05`, or `093005` with `separator: ''`.
String hhmmss(DateTime d, {String separator = ':'}) =>
    '${hhmm(d, separator: separator)}$separator${twoDigits(d.second)}';
