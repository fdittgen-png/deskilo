// SPDX-License-Identifier: AGPL-3.0-or-later

/// The calendar month (1-12) or quarter (1-4) a return covers, or null when
/// [start]..[end] is neither (an annual return, a part of a month). Moved here
/// from the application (#3333) for every country package; the host maps null
/// to its `period` problem.
({int? month, int? quarter})? monthOrQuarter(DateTime start, DateTime end) {
  final months = (end.year - start.year) * 12 + end.month - start.month + 1;
  if (start.day != 1 || end != DateTime(end.year, end.month + 1, 0)) {
    return null;
  }
  if (months == 1) return (month: start.month, quarter: null);
  if (months == 3 && (start.month - 1) % 3 == 0) {
    return (month: null, quarter: 1 + (start.month - 1) ~/ 3);
  }
  return null;
}
