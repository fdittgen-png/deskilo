// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1909 A — the event feed asks in the order its index holds. Driven over
// the real Supabase client against a scripted wire, so what is asserted
// is the request PostgREST receives:
//   * newest first as `created_at.desc.nullsfirst,id.desc.nullsfirst` — the old
//     default `nullslast` could not use events_workspace_created_idx and
//     sorted the whole workspace (713 rows scanned for 100 on dev; 101
//     with this order, an incremental sort on the id tie-breaker);
//   * decisions for 250 events in three bounded `in.(…)` requests,
//     totally ordered;
//   * two feed reads at once share ONE timeout sweep.
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/features/events/data/supabase_event_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _json = {'content-type': 'application/json'};

void main() {
  late List<Uri> gets;
  late int sweeps;
  late Completer<void> sweepGate;

  SupabaseEventRepository repo() {
    final client = SupabaseClient(
      'https://events.example',
      'anon',
      httpClient: MockClient((r) async {
        if (r.url.path == '/rest/v1/rpc/sweep_pending_events') {
          sweeps++;
          await sweepGate.future;
          return http.Response('null', 200, headers: _json, request: r);
        }
        gets.add(r.url);
        return http.Response(jsonEncode([]), 200, headers: _json, request: r);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    return SupabaseEventRepository(client);
  }

  setUp(() {
    gets = [];
    sweeps = 0;
    sweepGate = Completer()..complete();
  });

  test(
    'the feed orders newest first the way the index does, id last',
    () async {
      await repo().fetchEvents('ws-1');
      expect(
        gets.single.queryParameters['order'],
        'created_at.desc.nullsfirst,id.desc.nullsfirst',
      );
      expect(gets.single.queryParameters['limit'], '100');
    },
  );

  test('the export pages in the same total order', () async {
    await repo().fetchEvents('ws-1', limit: 0);
    expect(
      gets.first.queryParameters['order'],
      'created_at.desc.nullsfirst,id.desc.nullsfirst',
    );
  });

  test(
    'decisions for 250 events: three bounded requests, totally ordered',
    () async {
      final ids = [for (var i = 0; i < 250; i++) 'e$i'];
      await repo().fetchDecisions('ws-1', ids);
      final requests = [
        for (final u in gets)
          if (u.path == '/rest/v1/event_decisions') u,
      ];
      expect(requests, hasLength(3));
      for (final u in requests) {
        final inList = u.queryParameters['event_id']!;
        expect(inList.split(',').length, lessThanOrEqualTo(100));
        expect(
          u.queryParameters['order'],
          'decided_at.asc.nullslast,id.asc.nullslast',
        );
      }
    },
  );

  test('two feed reads at once share one timeout sweep', () async {
    sweepGate = Completer();
    final r = repo();
    final a = r.fetchEvents('ws-1');
    final b = r.fetchEvents('ws-1');
    await Future<void>.delayed(Duration.zero);
    sweepGate.complete();
    await Future.wait([a, b]);
    expect(sweeps, 1);
    await r.fetchEvents('ws-1');
    expect(sweeps, 2, reason: 'a later read sweeps again');
  });
}
