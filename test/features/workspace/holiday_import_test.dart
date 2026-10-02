// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2051 — the open-data holiday source: what it is parsed into, which
// countries it covers, and that every failure is named.
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/core/country/country_catalog.dart';
import 'package:deskilo/features/workspace/data/nager_holiday_source.dart';
import 'package:deskilo/features/workspace/domain/holiday_import.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Three entries in the shape date.nager.at answers, plus noise.
const _body = [
  {
    'date': '2026-01-01',
    'localName': 'Neujahr',
    'name': "New Year's Day",
    'counties': null,
    'types': ['Public'],
  },
  {
    'date': '2026-01-06',
    'localName': 'Heilige Drei Könige',
    'name': 'Epiphany',
    'counties': ['DE-BW', 'DE-BY', 'DE-ST'],
    'types': ['Public'],
  },
  {
    'date': '2026-03-17',
    'localName': 'Bank day',
    'name': 'Bank day',
    'counties': null,
    'types': ['Bank'],
  },
  {
    'date': 'not a date',
    'types': ['Public'],
  },
  'garbage',
];

void main() {
  group('parseNagerHolidays', () {
    final days = parseNagerHolidays(_body);

    test('keeps public days only and skips malformed entries', () {
      expect(days.map((d) => d.localName), ['Neujahr', 'Heilige Drei Könige']);
      expect(days.first.day, DateTime(2026));
      expect(days.first.name, "New Year's Day");
    });

    test('a regional day carries its subdivisions', () {
      expect(days.first.regions, isEmpty);
      expect(days.last.regions, ['DE-BW', 'DE-BY', 'DE-ST']);
      expect(holidayRegions(days), ['DE-BW', 'DE-BY', 'DE-ST']);
    });

    test('nationwide only unless a region is chosen', () {
      expect(holidaysFor(days, null).map((d) => d.localName), ['Neujahr']);
      expect(holidaysFor(days, 'DE-BY'), hasLength(2));
      expect(holidaysFor(days, 'DE-BE'), hasLength(1));
    });

    test('one entry per date', () {
      final twice = parseNagerHolidays([
        _body.first,
        {...(_body.first as Map<String, Object?>), 'localName': 'Neujahrstag'},
      ]);
      expect(twice, hasLength(2));
      expect(holidaysFor(twice, null), hasLength(1));
    });

    test('a body that is not a list is the source being unavailable', () {
      expect(
        () => parseNagerHolidays({'error': 'x'}),
        throwsA(isA<HolidaySourceUnavailable>()),
      );
    });
  });

  test('the coverage table names every country of the catalogue', () {
    expect(
      holidaySourceCoverage.keys.toSet(),
      {for (final c in CountryCatalog.countries) c.code},
      reason:
          'a country the app offers without a holiday source would '
          'open an import sheet that can only fail',
    );
    for (final regional in ['DE', 'CH', 'ES', 'US', 'CA', 'AT', 'GB']) {
      expect(holidaySourceCoverage[regional], isTrue, reason: regional);
    }
  });

  group('NagerHolidaySource', () {
    NagerHolidaySource over(
      MockClientHandler handler, {
      Duration timeout = const Duration(seconds: 10),
    }) => NagerHolidaySource(
      transport: () => MockClient(handler),
      timeout: timeout,
    );

    test('asks the public endpoint for the year and the country', () async {
      Uri? asked;
      final days = await over((request) async {
        asked = request.url;
        return http.Response.bytes(utf8.encode(jsonEncode(_body)), 200);
      }).fetch('de', 2026);
      expect(
        asked.toString(),
        'https://date.nager.at/api/v3/PublicHolidays/2026/DE',
      );
      expect(days, hasLength(2));
    });

    test('a refusal, a timeout, an unreadable body and no network are all '
        'HolidaySourceUnavailable', () async {
      final failures = <MockClientHandler>[
        (_) async => http.Response('', 404),
        (_) async => http.Response('<html>', 200),
        (_) async => throw http.ClientException('offline'),
        (_) => Completer<http.Response>().future,
      ];
      for (final handler in failures) {
        await expectLater(
          over(
            handler,
            timeout: const Duration(milliseconds: 20),
          ).fetch('DE', 2026),
          throwsA(isA<HolidaySourceUnavailable>()),
        );
      }
    });
  });
}
