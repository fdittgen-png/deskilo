// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C1 — the strict adapter of `my_reservations_page_v1`, over a fake
// PostgREST: the question leaves as the host expects it (UTC instants, the
// direction, both cursor fields), the answer is typed with the host
// attached as its source, an unknown field is ignored, and every refusal
// the host raises on purpose arrives as its own typed failure. A malformed
// or incompatible answer is a failure too, never an empty page. The pure
// window rule beside it: the default span, the ceiling, the inclusive days.
import 'dart:convert';

import 'package:deskilo/core/backend/operation_context.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/core/settings/settings_capture.dart';
import 'package:deskilo/features/reservations/data/context_my_reservations_repository.dart';
import 'package:deskilo/features/reservations/domain/my_reservations.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _installation = 'inst-w-a';

/// The host's registry as the context captured it: a 10-day default and a
/// 90-day ceiling, numbers no literal would guess.
List<SettingDefinition> _rows({int windowDays = 10, int maxDays = 90}) => [
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

WorkspaceContext _context({List<SettingDefinition>? rows}) => WorkspaceContext(
      identity: const CanonicalIdentity(issuer: 'https://p.test', subject: 'sub-1'),
      target: WorkspaceTarget.local(installationId: _installation, workspaceId: 'ws-1'),
      workspaceLocalUserId: 'local-1',
      personalEpoch: 1,
      workspaceEpoch: 1,
      settings: SettingsCapture(
        const SettingsIdentity(installation: 'https://w-a.test', workspaceId: 'ws-1', principal: 'local-1'),
        SettingsSet.defaults(rows ?? _rows()),
      ),
      timezone: 'Europe/Paris',
    );

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

/// A host answering the one RPC with what the test queued.
class _Host {
  final List<Map<String, dynamic>> received = [];
  Object? answer = _page();
  ({int status, String code, String message})? refusal;

  Future<http.Response> handle(http.Request request) async {
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

ContextMyReservationsRepository _adapter(
  _Host host, {
  bool withContext = true,
  List<SettingDefinition>? rows,
}) {
  final client = SupabaseClient(
    'http://127.0.0.1:54321',
    'sb_publishable_test',
    httpClient: MockClient(host.handle),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return ContextMyReservationsRepository(
    context: () async => withContext ? _context(rows: rows) : null,
    clientFor: (id) {
      expect(id, _installation, reason: 'the context\'s host, no other');
      return client;
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
      await _adapter(host).page(_query);
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

    test('no workspace context: a typed refusal, and the host is never asked', () async {
      final host = _Host();
      await expectLater(
        _adapter(host, withContext: false).page(_query),
        throwsA(isA<MyReservationsRefused>().having((e) => e.failure, 'failure', MyReservationsFailure.noContext)),
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
      final page = await _adapter(host).page(_query);
      expect(page.source, _installation);
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

    test('an empty page is empty, not a failure', () async {
      final host = _Host()..answer = _page(items: const []);
      final page = await _adapter(host).page(_query);
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.next, isNull);
    });

    Future<void> expectFailure(Object? answer, MyReservationsFailure failure) async {
      final host = _Host()..answer = answer;
      await expectLater(
        _adapter(host).page(_query),
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
        _adapter(host).page(_query),
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
      await expectLater(_adapter(host).page(_query), throwsA(isA<PostgrestException>()));
    });
  });

  group('the limits', () {
    test('are the host\'s captured settings, asked of no server', () async {
      final host = _Host();
      final limits = await _adapter(host).limits();
      expect((limits.windowDays, limits.maxDays), (10, 90));
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

    test('no workspace context is the same typed refusal as for a page', () async {
      await expectLater(
        _adapter(_Host(), withContext: false).limits(),
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
}
