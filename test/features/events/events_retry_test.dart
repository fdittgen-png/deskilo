// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3103 (PERF-10) — the badge's feed is listened to for the whole session.
// Under Riverpod's default policy a failing read was tried 10 times over
// about 38 s, sweeping each time; a missing sweep function failed the feed
// outright. Counted over HTTP on the real repository.
import 'dart:convert';

import 'package:deskilo/core/cache/read_retry.dart';
import 'package:deskilo/features/events/data/supabase_event_repository.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _json = {'content-type': 'application/json'};

const _ws = Workspace(
  id: 'ws-a',
  name: 'ws-a',
  countryCode: 'DE',
  currencyCode: 'EUR',
  timezone: 'Europe/Berlin',
  inviteCode: 'GOODCODE22',
);

void main() {
  late int sweeps;
  late int lists;

  ProviderContainer start({
    required http.Response Function(http.Request) sweep,
    required http.Response Function(http.Request) list,
  }) {
    sweeps = 0;
    lists = 0;
    final client = SupabaseClient(
      'https://events.example',
      'anon',
      httpClient: MockClient((r) async {
        if (r.url.path == '/rest/v1/rpc/sweep_pending_events') {
          sweeps++;
          return sweep(r);
        }
        lists++;
        return list(r);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    final container = ProviderContainer(
      retry: readRetry,
      overrides: [
        eventRepositoryProvider.overrideWithValue(
          SupabaseEventRepository(client),
        ),
        currentWorkspaceProvider.overrideWith((ref) async => _ws),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  http.Response error(http.Request r, int status, String code) => http.Response(
    jsonEncode({'code': code, 'message': code, 'details': null, 'hint': null}),
    status,
    headers: _json,
    request: r,
  );

  test('a missing sweep function: one sweep, and the feed loads', () async {
    final c = start(
      sweep: (r) => error(r, 404, 'PGRST202'),
      list: (r) => http.Response('[]', 200, headers: _json, request: r),
    );
    final sub = c.listen(eventsProvider, (_, _) {});
    addTearDown(sub.close);
    await expectLater(c.read(eventsProvider.future), completion(isEmpty));
    expect(sweeps, 1);
  });

  test('a denied read is read once, not ten times', () async {
    final c = start(
      sweep: (r) => http.Response('null', 200, headers: _json, request: r),
      list: (r) => error(r, 403, '42501'),
    );
    final sub = c.listen(eventsProvider, (_, _) {});
    addTearDown(sub.close);
    await expectLater(c.read(eventsProvider.future), throwsA(anything));
    // Longer than the policy's two quick tries would take.
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(lists, 1);
    expect(sweeps, 1);
  });

  test('a transient failure is tried twice more, then stops', () async {
    final c = start(
      sweep: (r) => http.Response('null', 200, headers: _json, request: r),
      list: (r) => error(r, 503, '503'),
    );
    final sub = c.listen(eventsProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(const Duration(seconds: 6));
    expect(lists, 3);
  });
}
