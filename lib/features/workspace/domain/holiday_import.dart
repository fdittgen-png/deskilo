// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2051 — public holidays imported from an open-data source.
//
// The SQL generator of #1274 (`public_holidays(country, year)`) knows FR
// and DE by hand. Every other country the catalogue offers is covered by
// ONE open-data source, Nager.Date (date.nager.at): public, no API key,
// `Access-Control-Allow-Origin: *`, MIT-licensed, regional days listed
// per ISO 3166-2 subdivision in `counties`. OpenHolidays API was measured
// too (ODbL data, European subdivisions) but lacks CY, DK, FI, GR, NO,
// GB, US and CA, so a second source would add a path and cover nothing
// Nager.Date misses. The coverage is the table below, pinned by a test
// against [CountryCatalog].
//
// The source decides only which days exist. Whether a day may become a
// closure day — owner only, invoiced months locked and named, no
// duplicates — is still the server's (`import_closure_days`).
//
// Pure Dart: no Flutter, no l10n, no HTTP.
library;

import 'holiday_regions.dart';

/// The one open-data source, as the sheet credits it.
const holidaySourceName = 'Nager.Date (date.nager.at)';

/// Every country of `CountryCatalog`, and whether the source lists
/// regional holidays for it (measured 2026-10-01 on the 2026 calendar).
/// `true` means the import offers a region picker.
const holidaySourceCoverage = <String, bool>{
  'AT': true,
  'BE': false,
  'BG': false,
  'CY': false,
  'CZ': false,
  'DE': true,
  'DK': false,
  'EE': false,
  'ES': true,
  'FI': false,
  'FR': false,
  'GR': false,
  'HR': false,
  'HU': false,
  'IE': false,
  'IT': true,
  'LT': false,
  'LU': false,
  'LV': false,
  'MT': false,
  'NL': false,
  'PL': false,
  'PT': true,
  'RO': false,
  'SE': false,
  'SI': false,
  'SK': false,
  'CH': true,
  'NO': false,
  'GB': true,
  'US': true,
  'CA': true,
};

/// One day as the source names it.
typedef ImportedHoliday = ({
  DateTime day,

  /// The official name in the country's language — "Fronleichnam".
  String localName,

  /// The English name — "Corpus Christi".
  String name,

  /// ISO 3166-2 codes where the day is a holiday; empty = nationwide.
  List<String> regions,
});

/// The source could not answer: offline, slow, refused, or spoke
/// something that is not a holiday list. Never an empty list in disguise.
class HolidaySourceUnavailable implements Exception {
  const HolidaySourceUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'HolidaySourceUnavailable: $reason';
}

/// Where the days come from. The data layer talks HTTP; tests hand in a
/// list.
abstract interface class HolidaySource {
  /// The public holidays of [country] in [year], nationwide and regional.
  /// Throws [HolidaySourceUnavailable] when there is no honest answer.
  Future<List<ImportedHoliday>> fetch(String country, int year);
}

/// Parses `/api/v3/PublicHolidays/{year}/{country}`. Only days typed
/// `Public` are kept: bank, school, optional and observance days are not
/// days a space closes by law. A malformed entry is skipped; a body that
/// is not a list is the source being unavailable.
List<ImportedHoliday> parseNagerHolidays(Object? body) {
  if (body is! List) {
    throw const HolidaySourceUnavailable('not a holiday list');
  }
  final seen = <String>{};
  final days = <ImportedHoliday>[];
  for (final entry in body) {
    if (entry is! Map) continue;
    final date = DateTime.tryParse('${entry['date']}');
    final types = entry['types'];
    if (date == null || types is! List || !types.contains('Public')) continue;
    final counties = entry['counties'];
    final regions = [
      if (counties is List)
        for (final c in counties)
          if (c is String && c.isNotEmpty) c,
    ];
    final local = '${entry['localName'] ?? ''}'.trim();
    final english = '${entry['name'] ?? ''}'.trim();
    final day = DateTime(date.year, date.month, date.day);
    // The same date twice (two regional entries) stays two lines only
    // when their names differ; an exact repeat is noise.
    if (!seen.add('${day.toIso8601String()}|$local|${regions.join(',')}')) {
      continue;
    }
    days.add((
      day: day,
      localName: local.isEmpty ? english : local,
      name: english,
      regions: regions,
    ));
  }
  days.sort((a, b) => a.day.compareTo(b.day));
  return days;
}

/// The regions the list names, sorted by region name (#2079) — the
/// picker's entries, as ISO codes.
List<String> holidayRegions(List<ImportedHoliday> days) =>
    sortHolidayRegions([for (final d in days) ...d.regions]);

/// The days that apply in [region]: nationwide ones always, regional ones
/// only in their region. `null` = nationwide only. One entry per date —
/// a workspace has one closure day per date, so the first name wins.
List<ImportedHoliday> holidaysFor(List<ImportedHoliday> days, String? region) {
  final dates = <DateTime>{};
  return [
    for (final d in days)
      if ((d.regions.isEmpty ||
              (region != null && d.regions.contains(region))) &&
          dates.add(d.day))
        d,
  ];
}
