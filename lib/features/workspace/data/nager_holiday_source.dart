// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2051 — the open-data holiday source over HTTP.
//
// A documented client path rather than an edge function: Nager.Date needs
// no key (nothing secret ships in the app) and answers every origin
// (`Access-Control-Allow-Origin: *`), so the web build reaches it as the
// mobile and desktop builds do. Only an owner opening the import sheet
// calls it. Bounded by [timeout]; every failure is a
// [HolidaySourceUnavailable], never an empty list.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/holiday_import.dart';

class NagerHolidaySource implements HolidaySource {
  NagerHolidaySource({
    http.Client Function()? transport,
    this.timeout = const Duration(seconds: 10),
  }) : _transport = transport ?? http.Client.new;

  final http.Client Function() _transport;
  final Duration timeout;

  static Uri uriFor(String country, int year) => Uri.https(
    'date.nager.at',
    '/api/v3/PublicHolidays/$year/${country.toUpperCase()}',
  );

  @override
  Future<List<ImportedHoliday>> fetch(String country, int year) async {
    final client = _transport();
    try {
      final response = await client
          .get(uriFor(country, year), headers: {'accept': 'application/json'})
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw HolidaySourceUnavailable('HTTP ${response.statusCode}');
      }
      return parseNagerHolidays(jsonDecode(utf8.decode(response.bodyBytes)));
    } on TimeoutException catch (e, st) {
      // trace-exempt: rethrown typed; the sheet traces it.
      Error.throwWithStackTrace(
        HolidaySourceUnavailable('timed out after ${e.duration}'),
        st,
      );
    } on FormatException catch (e, st) {
      // trace-exempt: rethrown typed; the sheet traces it.
      Error.throwWithStackTrace(
        HolidaySourceUnavailable('unreadable answer: ${e.message}'),
        st,
      );
    } on http.ClientException catch (e, st) {
      // trace-exempt: rethrown typed; the sheet traces it.
      Error.throwWithStackTrace(
        HolidaySourceUnavailable('unreachable: ${e.message}'),
        st,
      );
    } finally {
      client.close();
    }
  }
}
