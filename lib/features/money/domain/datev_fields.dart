// SPDX-License-Identifier: AGPL-3.0-or-later

import 'book_profile.dart';

/// #2365 — DATEV's field limits: `Belegfeld 1` holds 36 characters and
/// `Buchungstext` 60. The importer rejects the row, or the whole stack,
/// above them, so the text is cut here, by character and never in the
/// middle of one.
String datevClip(String text, int max) {
  final chars = text.runes.toList();
  return chars.length <= max ? text : String.fromCharCodes(chars.take(max));
}

/// Header field 27, the SKR: the digits of the chart's name ('SKR03' ->
/// '03'), or empty when the name carries none.
String datevSkrDigits(String chart) =>
    RegExp(r'\d+').firstMatch(chart)?.group(0) ?? '';

/// #2365 — header field 13: the first day of the fiscal year that contains
/// [from], for a fiscal year starting on [month]/[day] (the book profile).
DateTime _fiscalYearStart(int month, int day, DateTime from) {
  final thisYear = DateTime(from.year, month, day);
  return thisYear.isAfter(from)
      ? DateTime(from.year - 1, month, day)
      : thisYear;
}

/// The fiscal-year start the book profiles agree on for the period
/// [from]..[to]: each issuer's latest version in force at [to]; null when
/// there is none or the issuers disagree (the header then says 1 January).
DateTime? datevProfileFiscalStart(
  List<BookProfile> profiles,
  DateTime from,
  DateTime to,
) {
  final latest = <String, BookProfile>{};
  for (final p in profiles) {
    if (p.effectiveFrom.isAfter(to)) continue;
    final seen = latest[p.issuerSiteId];
    if (seen == null || p.effectiveFrom.isAfter(seen.effectiveFrom)) {
      latest[p.issuerSiteId] = p;
    }
  }
  final starts = {
    for (final p in latest.values)
      _fiscalYearStart(p.fiscalYearStartMonth, p.fiscalYearStartDay, from),
  };
  return starts.length == 1 ? starts.single : null;
}
