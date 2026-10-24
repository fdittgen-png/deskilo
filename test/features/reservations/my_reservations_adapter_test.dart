// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 — the strict adapter of `my_reservations_page_v1`, over a fake
// PostgREST: the question leaves as the host expects it (UTC instants, the
// direction, both cursor fields), the answer is typed with the host
// attached as its source, an unknown field is ignored, and every refusal
// the host raises on purpose arrives as its own typed failure. A malformed
// or incompatible answer is a failure too, never an empty page. C2: the
// source's own verified host is asked, a host that is another installation
// or cannot be reached is refused, the workspaces' zones come from the same
// host, and the limits are the personal home's platform settings. The pure
// window rule beside it: the default span, the ceiling, the inclusive days.
import 'dart:convert';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_target.dart';
import 'package:deskilo/core/backend/connection_outcome.dart';
import 'package:deskilo/core/backend/context_clients.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/reservations/data/host_my_reservations_repository.dart';
import 'package:deskilo/features/reservations/domain/my_reservations.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _installation = 'inst-w-a';

/// The personal home's platform registry: a 10-day default, a 90-day
/// ceiling, three hosts at once and 7 seconds, numbers no literal would
/// guess.
List<SettingDefinition> _rows({int windowDays = 10, int maxDays = 90}) => [
      SettingDefinition(
        key: 'personal.read_concurrency',
        type: SettingType.integer,
        defaultValue: 3,
        group: 'personal',
        scopes: const {SettingScope.platform},
      ),
      SettingDefinition(
        key: 'personal.read_timeout_seconds',
        type: SettingType.integer,
        defaultValue: 7,
        group: 'personal',
        scopes: const {SettingScope.platform},
      ),
      SettingDefinition(
        key: 'personal.reservation_window_days',
        type: SettingType.integer,
        defaultValue: windowDays,
        group: 'personal',
        scopes: const {SettingScope.platform},
      ),
      SettingDefinition(
        key: 'personal.reservation_max_window_days',
        type: SettingType.integer,
        defaultValue: maxDays,
        group: 'personal',
        scopes: const {SettingScope.platform},
      ),
    ];

const _source = MyReservationsSource(installationId: _installation, workspaceIds: ['ws-1']);

Map<String, Object?> _item(String id, {String status = 'reserved'}) => {
      'id': id,
      'workspace_id': 'ws-1',
      'workspace_name': 'One',
      'place_kind': 'seat',
      'place_id': 'seat-1',
      'place_label': 'A1',
      'starts_at': '2031-03-02T08:00:00+00:00',
      'ends_at': '2031-03-02T12:00:00+00:00',
      'status': status,
      'checked_in_at': null,
      'checked_out_at': null,
    };

Map<String, Object?> _page({
  List<Map<String, Object?>>? items,
  bool hasMore = false,
  Object? next,
  int schemaVersion = 1,
}) =>
    {
      'schema_version': schemaVersion,
      'items': items ?? [_item('r-1')],
      'has_more': hasMore,
      'next': next,
    };

/// A host answering the one RPC with what the test queued, and its
/// workspace rows' zones.
class _Host {
  final List<Map<String, dynamic>> received = [];
  final List<Uri> zoneReads = [];
  Object? answer = _page();
  ({int status, String code, String message})? refusal;
  List<Map<String, Object?>> zones = [
    {'id': 'ws-1', 'timezone': 'Europe/Paris'},
  ];
  bool zonesFail = false;

  Future<http.Response> handle(http.Request request) async {
    if (request.url.path == '/rest/v1/workspaces') {
      zoneReads.add(request.url);
      return http.Response(
        zonesFail ? jsonEncode({'code': '57014', 'message': 'timeout'}) : jsonEncode(zones),
        zonesFail ? 500 : 200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    }
    expect(request.url.path, '/rest/v1/rpc/my_reservations_page_v1');
    received.add(jsonDecode(request.body) as Map<String, dynamic>);
    final r = refusal;
    if (r != null) {
      return http.Response(
        jsonEncode({'code': r.code, 'message': r.message, 'details': null, 'hint': null}),
        r.status,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(
      jsonEncode(answer),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

HostMyReservationsRepository _adapter(
  _Host host, {
  bool signedIn = true,
  List<SettingDefinition>? rows,
  Future<ResolvedWorkspaceHost> Function()? resolve,
}) {
  final client = SupabaseClient(
    'http://127.0.0.1:54321',
    'sb_publishable_test',
    httpClient: MockClient(host.handle),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return HostMyReservationsRepository(
    platformSettings: () async => signedIn ? SettingsSet.defaults(rows ?? _rows()) : null,
    hostOf: (source) {
      expect(source, _source, reason: 'the source asked, no other');
      return resolve?.call() ??
          Future.value(ResolvedWorkspaceHost(
            installationId: _installation,
            client: client,
            localUserId: 'local-1',
          ));
    },
  );
}

final _query = MyReservationsQuery(
  from: DateTime.utc(2031, 3),
  to: DateTime.utc(2031, 4),
);

void main() {
  group('the question', () {
    test('leaves as the host expects it: UTC instants, direction, no cursor', () async {
      final host = _Host();
      await _adapter(host).page(_source, _query);
      expect(host.received.single, {
        'p_from': '2031-03-01T00:00:00.000Z',
        'p_to': '2031-04-01T00:00:00.000Z',
        'p_workspace_id': null,
        'p_direction': 'asc',
        'p_after_start': null,
        'p_after_id': null,
      });
    });

    test('a continuation names both cursor fields and keeps the rest', () async {
      final host = _Host();
      final next = MyReservationsCursor(afterStart: DateTime.utc(2031, 3, 2, 8), afterId: 'r-1');
      await _adapter(host).page(
        _source,
        MyReservationsQuery(
          from: _query.from,
          to: _query.to,
          workspaceId: 'ws-1',
          direction: MyReservationsDirection.descending,
        ).continuedAfter(next),
      );
      expect(host.received.single, {
        'p_from': '2031-03-01T00:00:00.000Z',
        'p_to': '2031-04-01T00:00:00.000Z',
        'p_workspace_id': 'ws-1',
        'p_direction': 'desc',
        'p_after_start': '2031-03-02T08:00:00.000Z',
        'p_after_id': 'r-1',
      });
    });

    test('equal queries are one feed; a changed window, filter, direction or cursor is another', () {
      final a = MyReservationsQuery(from: _query.from, to: _query.to);
      final b = MyReservationsQuery(from: _query.from, to: _query.to);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(MyReservationsQuery(from: _query.from, to: _query.to, workspaceId: 'ws-1')));
      expect(a, isNot(MyReservationsQuery(from: _query.from, to: _query.to, direction: MyReservationsDirection.descending)));
      expect(a, isNot(a.continuedAfter(MyReservationsCursor(afterStart: _query.from, afterId: 'x'))));
    });

    test('a host that is another installation is refused, and not asked', () async {
      final host = _Host();
      final other = SupabaseClient(
        'http://127.0.0.1:54322',
        'sb_publishable_test',
        httpClient: MockClient(host.handle),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await expectLater(
        _adapter(host, resolve: () async => ResolvedWorkspaceHost(
          installationId: 'inst-other',
          client: other,
          localUserId: 'local-9',
        )).page(_source, _query),
        throwsA(isA<MyReservationsRefused>()
            .having((e) => e.failure, 'failure', MyReservationsFailure.hostUnavailable)),
      );
      expect(host.received, isEmpty);
    });

    test('an unverified or unconnected host is the same typed refusal', () async {
      final host = _Host();
      final refused = throwsA(isA<MyReservationsRefused>()
          .having((e) => e.failure, 'failure', MyReservationsFailure.hostUnavailable));
      await expectLater(
        _adapter(host, resolve: () async => throw const UnverifiedInstallation(_installation))
            .page(_source, _query),
        refused,
      );
      await expectLater(
        _adapter(host, resolve: () async =>
                throw ConnectionFailure(_installation, ConnectionFailureReason.notConnected))
            .page(_source, _query),
        refused,
      );
      expect(host.received, isEmpty);
    });
  });

  group('the answer', () {
    test('is typed, carries the asked host as its source and ignores an unknown field', () async {
      final host = _Host()
        ..answer = _page(
          items: [
            {..._item('r-1', status: 'checked_in'), 'checked_in_at': '2031-03-02T08:05:00+00:00', 'extra': 1},
            {..._item('r-2'), 'place_kind': 'office', 'place_id': null, 'place_label': ''},
          ],
          hasMore: true,
          next: {'after_start': '2031-03-02T08:00:00+00:00', 'after_id': 'r-2', 'extra': true},
        );
      final page = await _adapter(host).page(_source, _query);
      expect(page.source, _installation);
      expect(page.zones, {'ws-1': 'Europe/Paris'}, reason: 'the zone of the workspace, from the same host');
      expect(host.zoneReads.single.queryParameters['id'], 'in.("ws-1")');
      expect(page.hasMore, isTrue);
      expect(page.next, MyReservationsCursor(afterStart: DateTime.utc(2031, 3, 2, 8), afterId: 'r-2'));
      final first = page.items.first;
      expect(first.status, ReservationStatus.checkedIn);
      expect(first.checkedInAt, DateTime.utc(2031, 3, 2, 8, 5));
      expect(first.startsAt.isUtc, isTrue);
      expect(first.placeKind, MyReservationPlaceKind.seat);
      expect(first.workspaceName, 'One');
      final second = page.items.last;
      expect(second.placeKind, MyReservationPlaceKind.office);
      expect(second.placeId, isNull);
      expect(second.placeLabel, '');
    });

    test('a zone read that fails leaves the bookings, without zones', () async {
      final host = _Host()..zonesFail = true;
      final page = await _adapter(host).page(_source, _query);
      expect(page.items.single.id, 'r-1');
      expect(page.zones, isEmpty);
    });

    test('an empty page is empty, not a failure', () async {
      final host = _Host()..answer = _page(items: const []);
      final page = await _adapter(host).page(_source, _query);
      expect(host.zoneReads, isEmpty, reason: 'no workspace named, no zone asked');
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.next, isNull);
    });

    Future<void> expectFailure(Object? answer, MyReservationsFailure failure) async {
      final host = _Host()..answer = answer;
      await expectLater(
        _adapter(host).page(_source, _query),
        throwsA(isA<MyReservationsRefused>().having((e) => e.failure, 'failure', failure)),
      );
    }

    test('another schema version is incompatible', () =>
        expectFailure(_page(schemaVersion: 2), MyReservationsFailure.incompatible));

    test('a missing has_more is malformed, never defaulted', () =>
        expectFailure((_page()..remove('has_more')), MyReservationsFailure.malformed));

    test('an unknown status is malformed, never a guess', () =>
        expectFailure(_page(items: [_item('r-1', status: 'vanished')]), MyReservationsFailure.malformed));

    test('more pages announced without a cursor is malformed', () =>
        expectFailure(_page(hasMore: true), MyReservationsFailure.malformed));

    test('an answer that is not an object is malformed', () =>
        expectFailure([_item('r-1')], MyReservationsFailure.malformed));
  });

  group('the host\'s refusals', () {
    Future<void> expectRefusal(
      ({int status, String code, String message}) refusal,
      MyReservationsFailure failure,
    ) async {
      final host = _Host()..refusal = refusal;
      await expectLater(
        _adapter(host).page(_source, _query),
        throwsA(isA<MyReservationsRefused>()
            .having((e) => e.failure, 'failure', failure)
            .having((e) => e.detail, 'detail', refusal.message)),
      );
    }

    test('an older host without the read is unsupported', () => expectRefusal(
        (status: 404, code: 'PGRST202', message: 'Could not find the function'),
        MyReservationsFailure.unsupported));

    test('42501 is forbidden', () => expectRefusal(
        (status: 403, code: '42501', message: 'personal read unavailable'),
        MyReservationsFailure.forbidden));

    test('22023 is an invalid question', () => expectRefusal(
        (status: 400, code: '22023', message: 'the window is longer than 400 days'),
        MyReservationsFailure.invalid));

    test('a registry without the personal rows is misconfigured', () => expectRefusal(
        (status: 400, code: 'P0001', message: 'unknown setting personal.reservation_page_size'),
        MyReservationsFailure.misconfigured));

    test('any other database error passes through untyped', () async {
      final host = _Host()..refusal = (status: 500, code: '57014', message: 'canceling statement');
      await expectLater(_adapter(host).page(_source, _query), throwsA(isA<PostgrestException>()));
    });
  });

  group('the limits', () {
    test('are the personal home\'s platform settings, asked of no workspace host', () async {
      final host = _Host();
      final limits = await _adapter(host).limits();
      expect((limits.windowDays, limits.maxDays), (10, 90));
      expect((limits.concurrency, limits.timeout), (3, const Duration(seconds: 7)));
      expect(host.received, isEmpty);
    });

    test('a registry without the rows is misconfigured, never a literal', () async {
      final host = _Host();
      await expectLater(
        _adapter(host, rows: const []).limits(),
        throwsA(isA<MyReservationsRefused>()
            .having((e) => e.failure, 'failure', MyReservationsFailure.misconfigured)),
      );
    });

    test('signed out is a typed refusal, never a default', () async {
      await expectLater(
        _adapter(_Host(), signedIn: false).limits(),
        throwsA(isA<MyReservationsRefused>()
            .having((e) => e.failure, 'failure', MyReservationsFailure.noContext)),
      );
    });

    test('a refusal or a host answer is final; only a transport failure is tried twice', () {
      expect(myReservationsRetry(0, const MyReservationsRefused(MyReservationsFailure.forbidden)), isNull);
      expect(myReservationsRetry(0, const PostgrestException(message: 'x')), isNull);
      expect(myReservationsRetry(0, StateError('socket')), const Duration(milliseconds: 200));
      expect(myReservationsRetry(1, StateError('socket')), const Duration(milliseconds: 400));
      expect(myReservationsRetry(2, StateError('socket')), isNull);
    });
  });

  group('the window', () {
    test('starts today and spans the default days', () {
      final w = MyReservationsWindow.fromToday(DateTime(2026, 5, 13, 10, 30), defaultDays: 31, maxDays: 400);
      expect(w.from, DateTime(2026, 5, 13));
      expect(w.to, DateTime(2026, 6, 13));
      expect(w.lastDay, DateTime(2026, 6, 12));
    });

    test('covers the chosen days inclusively, cut to the ceiling, never empty', () {
      final w = MyReservationsWindow.fromToday(DateTime(2026, 5, 13), defaultDays: 31, maxDays: 60);
      final chosen = w.covering(DateTime(2026, 6), DateTime(2026, 6, 10));
      expect(chosen.from, DateTime(2026, 6));
      expect(chosen.to, DateTime(2026, 6, 11));
      final cut = w.covering(DateTime(2026, 6), DateTime(2026, 9, 30));
      expect(cut.to, DateTime(2026, 7, 31), reason: '60 days from 1 June');
      final backwards = w.covering(DateTime(2026, 6, 10), DateTime(2026, 6));
      expect(backwards.to, DateTime(2026, 6, 11), reason: 'one day, the first');
      expect(cut.maxDays, 60);
    });
  });

  group('the host of a source', () {
    final client = SupabaseClient('http://127.0.0.1:54321', 'sb_publishable_test',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    const far = MyReservationsSource(installationId: 'inst-w-b', workspaceIds: ['ws-9']);
    const connectedFar = ConnectedInstallation(
      endpoint: BackendEndpoint('https://w-b.test', 'sb_publishable_b'),
      account: 'local-b',
      installationId: 'inst-w-b',
    );

    test('my home\'s workspace is resolved on the signed-in installation, the pool not read',
        () async {
      final origins = <String?>[];
      var poolRead = false;
      final host = await resolveMyReservationsHost(
        const MyReservationsSource(installationId: _installation, workspaceIds: ['ws-1'], hostedHere: true),
        connected: () async {
          poolRead = true;
          return const [];
        },
        resolverFor: (origin) {
          origins.add(origin);
          return _Resolver(_installation, client);
        },
      );
      expect(origins, [null]);
      expect(poolRead, isFalse);
      expect(host.installationId, _installation);
    });

    test('another installation\'s workspace is resolved through its connected origin', () async {
      final origins = <String?>[];
      final asked = <String>[];
      await resolveMyReservationsHost(
        far,
        connected: () async => const [connectedFar],
        resolverFor: (origin) {
          origins.add(origin);
          return _Resolver('inst-w-b', client, asked: asked);
        },
      );
      expect(origins, ['https://w-b.test']);
      expect(asked, ['ws-9']);
    });

    test('an installation not connected here is refused typed, no resolver asked', () async {
      var resolved = false;
      await expectLater(
        resolveMyReservationsHost(
          far,
          connected: () async => const [],
          resolverFor: (_) {
            resolved = true;
            return _Resolver('inst-w-b', client);
          },
        ),
        throwsA(isA<MyReservationsRefused>()
            .having((e) => e.failure, 'failure', MyReservationsFailure.hostUnavailable)),
      );
      expect(resolved, isFalse);
    });
  });
}

class _Resolver implements WorkspaceHostResolver {
  _Resolver(this.installationId, this.client, {this.asked});

  final String installationId;
  final SupabaseClient client;
  final List<String>? asked;

  @override
  Future<ResolvedWorkspaceHost> resolve(String workspaceId) async {
    asked?.add(workspaceId);
    return ResolvedWorkspaceHost(installationId: installationId, client: client, localUserId: 'local');
  }
}
