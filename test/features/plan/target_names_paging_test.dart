// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (#2011): every authorised target name is read once whatever the
// server's row cap is, and a page that fails fails the whole read — never a
// shorter map that would leave a seat nameless.
import 'dart:convert';

import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/features/plan/data/supabase_floor_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A PostgREST stand-in holding [tables], answering at most [cap] rows.
SupabaseClient _client(
  Map<String, List<Map<String, Object?>>> tables, {
  int cap = 2,
  bool failSecondPage = false,
}) {
  var calls = 0;
  return SupabaseClient(
    'https://plan.example',
    'sb_publishable_plan',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      calls++;
      if (failSecondPage && calls == 2) {
        return http.Response('{"message":"down"}', 400, request: request);
      }
      final table = request.url.pathSegments.last;
      final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
      final limit = int.parse(request.url.queryParameters['limit'] ?? '1000');
      final rows = tables[table] ?? const <Map<String, Object?>>[];
      final end = [offset + limit, offset + cap, rows.length]
          .reduce((a, b) => a < b ? a : b);
      final page = offset >= rows.length ? <Map<String, Object?>>[] : rows.sublist(offset, end);
      return http.Response(jsonEncode(page), 200,
          headers: {'content-type': 'application/json'}, request: request);
    }),
  );
}

List<Map<String, Object?>> _rows(String p, int n) => [
      for (var i = 0; i < n; i++) {'id': '$p$i', 'name': '$p-name-$i'},
    ];

void main() {
  test('cap 2: three seats, three desks, three offices — all nine, once',
      () async {
    final repo = SupabaseFloorPlanRepository(
        _client({
          'seats': _rows('s', 3),
          'desks': _rows('d', 3),
          'offices': _rows('o', 3),
        }),
        InMemoryCacheStore());
    final names = await repo.fetchTargetNames('ws-1');
    expect(names.length, 9);
    expect(names['s2'], 's-name-2');
  });

  test('a failing second page fails the read, never a shorter map', () async {
    final repo = SupabaseFloorPlanRepository(
        _client({'seats': _rows('s', 3)}, failSecondPage: true),
        InMemoryCacheStore());
    await expectLater(repo.fetchTargetNames('ws-1'), throwsA(anything));
  });
}
