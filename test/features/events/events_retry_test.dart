// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3103 (PERF-10) — the badge's feed is listened to for the whole session.
// Under Riverpod's default policy a failing read was tried 10 times over
// about 38 s, sweeping each time; a missing sweep function failed the feed
// outright. Counted over HTTP on the real repository.
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/core/cache/read_retry.dart';
import 'package:deskilo/core/data/sweep_throttle.dart';
import 'package:deskilo/core/demo/data/event_repository.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/events/data/supabase_event_repository.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/real_async.dart';

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
          // An interval of 0: every read sweeps, so the counts below are
          // the retry policy's alone.
          SupabaseEventRepository(
            client,
            sweeps: SweepThrottle(
              clock: FixedClock(DateTime.utc(2026, 10, 31)),
              interval: () => Duration.zero,
            ),
          ),
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
    final failure = c.read(eventsProvider).error!;
    expect(lists, 1);
    expect(sweeps, 1);
    // The policy schedules no further try, so none can follow.
    expect(readRetry(0, failure), isNull);
  });

  // Counted on the repository, not over HTTP: the HTTP client retries a
  // 5xx itself, below the provider.
  test('a transient failure is tried twice more, then stops', () async {
    final repo = _TimingOut();
    final c = ProviderContainer(
      retry: readRetry,
      overrides: [
        eventRepositoryProvider.overrideWithValue(repo),
        currentWorkspaceProvider.overrideWith((ref) async => _ws),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(eventsProvider, (_, _) {});
    addTearDown(sub.close);
    await untilReal(
      () => c.read(eventsProvider) is AsyncError,
      what: 'the two quick retries',
    );
    expect(repo.reads, 3);
  });
}

class _TimingOut extends FakeEventRepository {
  int reads = 0;

  @override
  Future<List<WorkspaceEvent>> fetchEvents(
    String workspaceId, {
    int limit = 100,
  }) async {
    reads++;
    throw TimeoutException('events read (test)');
  }
}
