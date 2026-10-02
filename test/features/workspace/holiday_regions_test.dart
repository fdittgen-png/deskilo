// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2079 — the holiday region picker names regions instead of showing raw
// ISO 3166-2 codes.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/holiday_import.dart';
import 'package:deskilo/features/workspace/domain/holiday_regions.dart';
import 'package:flutter_test/flutter_test.dart';

ImportedHoliday _day(List<String> regions) => (
  day: DateTime(2026, 1, 6),
  localName: 'Tag',
  name: 'Day',
  regions: regions,
);

void main() {
  test('known codes read as their official or native name', () {
    expect(holidayRegionName('DE-BY'), 'Bayern');
    expect(holidayRegionName('CH-GE'), 'Genève');
    expect(holidayRegionName('ES-CT'), 'Catalunya');
    expect(holidayRegionName('US-CA'), 'California');
    expect(holidayRegionName('CA-QC'), 'Québec');
    expect(holidayRegionName('GB-ENG'), 'England');
  });

  test('an unknown code falls back to the code', () {
    expect(holidayRegionName('XX-99'), 'XX-99');
    expect(holidayRegionName(''), '');
  });

  test('regions sort by name, accents and case ignored, not by code', () {
    // By code: DE-BW, DE-BY, DE-SH, DE-TH; by name the order differs.
    expect(
      holidayRegions([
        _day(['DE-TH', 'DE-BY']),
        _day(['DE-SH', 'DE-BW', 'DE-BY']),
      ]),
      ['DE-BW', 'DE-BY', 'DE-SH', 'DE-TH'],
    );
    // ü folds to u: Zug < Zürich.
    expect(sortHolidayRegions(['CH-ZH', 'CH-ZG', 'CH-GE', 'CH-GL']), [
      'CH-GE',
      'CH-GL',
      'CH-ZG',
      'CH-ZH',
    ]);
    // Name order differs from code order: Saarland < Sachsen.
    expect(sortHolidayRegions(['DE-SN', 'DE-SL']), ['DE-SL', 'DE-SN']);
    expect(sortHolidayRegions(['US-NY', 'CA-AB', 'US-AL']), [
      'US-AL',
      'CA-AB',
      'US-NY',
    ]);
  });

  test('an unknown code sorts by itself among the names', () {
    expect(sortHolidayRegions(['DE-BY', 'ZZ-1', 'DE-BW']), [
      'DE-BW',
      'DE-BY',
      'ZZ-1',
    ]);
  });

  test('every subdivision code the source returned has a name', () {
    final fixture = jsonDecode(
      File('test/fixtures/holiday_regions/nager_subdivision_codes.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final codes = (fixture['codes'] as Map<String, dynamic>).map(
      (country, list) => MapEntry(country, (list as List).cast<String>()),
    );
    expect(codes.keys.toSet(), {
      'AT',
      'CA',
      'CH',
      'DE',
      'ES',
      'GB',
      'IT',
      'PT',
      'US',
    }, reason: 'every country the source gives regions for');
    final all = [for (final l in codes.values) ...l];
    expect(all.length, greaterThan(100));
    expect(
      [
        for (final c in all)
          if (!holidayRegionNames.containsKey(c)) c,
      ],
      isEmpty,
      reason: 'a code without a name would show raw in the picker',
    );
    for (final entry in codes.entries) {
      for (final c in entry.value) {
        expect(c, startsWith('${entry.key}-'));
        expect(holidayRegionName(c), isNot(c), reason: c);
      }
    }
  });

  test('every table entry is a well-formed code with a name', () {
    for (final e in holidayRegionNames.entries) {
      expect(e.value.trim(), isNotEmpty, reason: e.key);
      expect(e.key, matches(RegExp(r'^[A-Z]{2}-[A-Z0-9]{1,3}$')));
    }
  });
}
