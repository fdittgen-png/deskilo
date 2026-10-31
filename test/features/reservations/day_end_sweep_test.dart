// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3100 (PERF-3) — one `reservations` signal invalidates the day, two month
// windows, the upcoming list and the directory; each window read ran
// `sweep_day_end` first. Reads in flight together now share one sweep;
// a later read sweeps again. Counted over HTTP on the real repository.
import 'dart:async';

import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/features/reservations/data/supabase_reservation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _json = {'content-type': 'application/json'};

void main() {
  late int sweeps;
  late Completer<void> gate;

  SupabaseReservationRepository repo() {
    final client = SupabaseClient(
      'https://reservations.example',
      'anon',
      httpClient: MockClient((r) async {
        if (r.url.path == '/rest/v1/rpc/sweep_day_end') {
          sweeps++;
          await gate.future;
          return http.Response('null', 200, headers: _json, request: r);
        }
        return http.Response(
          '[]',
          200,
          headers: {..._json, 'content-range': '*/0'},
          request: r,
        );
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    return SupabaseReservationRepository(client, InMemoryCacheStore());
  }

  setUp(() {
    sweeps = 0;
    gate = Completer<void>();
  });

  test('four windows read together: one sweep', () async {
    final r = repo();
    final day = DateTime.utc(2026, 10, 31);
    final reads = [
      for (var i = 0; i < 4; i++)
        r.fetchWindow(
          'ws-a',
          from: day.add(Duration(days: i)),
          to: day.add(Duration(days: i + 1)),
        ),
    ];
    await pumpEventQueue();
    gate.complete();
    await Future.wait(reads);
    expect(sweeps, 1);
  });

  test('a later read sweeps again', () async {
    gate.complete();
    final r = repo();
    final day = DateTime.utc(2026, 10, 31);
    await r.fetchWindow(
      'ws-a',
      from: day,
      to: day.add(const Duration(days: 1)),
    );
    await r.fetchWindow(
      'ws-a',
      from: day.add(const Duration(days: 1)),
      to: day.add(const Duration(days: 2)),
    );
    expect(sweeps, 2);
  });
}
