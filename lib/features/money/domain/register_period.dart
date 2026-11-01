// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — the period a drill-through opens the invoice register on.

/// An inclusive window of days the invoice register is narrowed to, read
/// from the `from` / `to` address parameters (`YYYY-MM` or `YYYY-MM-DD`).
///
/// Anything missing, malformed or out of bounds yields no window at all
/// ([parse] returns null): the register then shows everything, as it
/// always did, instead of an error page.
class RegisterPeriod {
  const RegisterPeriod._(this.first, this.last);

  /// The first day of the window (inclusive).
  final DateTime first;

  /// The last day of the window (inclusive).
  final DateTime last;

  /// The years an address may name; a typo such as `0026-01` or
  /// `20260-01` is a malformed window, not a query over the ages.
  static const earliestYear = 2000;
  static const latestYear = 2100;

  /// The window named by [from] and [to]; a reversed pair is put in
  /// order. Null unless BOTH parameters are valid.
  static RegisterPeriod? parse(String? from, String? to) {
    final start = _bound(from, end: false);
    final stop = _bound(to, end: true);
    if (start == null || stop == null) return null;
    return start.isAfter(stop)
        ? RegisterPeriod._(_bound(to, end: false)!, _bound(from, end: true)!)
        : RegisterPeriod._(start, stop);
  }

  static final _shape = RegExp(r'^(\d{4})-(\d{2})(?:-(\d{2}))?$');

  static DateTime? _bound(String? text, {required bool end}) {
    final match = text == null ? null : _shape.firstMatch(text);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = match[3] == null ? null : int.parse(match[3]!);
    if (year < earliestYear || year > latestYear) return null;
    if (month < 1 || month > 12) return null;
    final lastOfMonth = DateTime(year, month + 1, 0).day;
    if (day != null && (day < 1 || day > lastOfMonth)) return null;
    return DateTime(year, month, day ?? (end ? lastOfMonth : 1));
  }

  /// Whether [moment] falls on a day of the window.
  bool contains(DateTime moment) {
    final day = DateTime(moment.year, moment.month, moment.day);
    return !day.isBefore(first) && !day.isAfter(last);
  }
}
