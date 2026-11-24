// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C3 — the row actions over two fake hosts: Cancel and Check in
// leave on the client of the host the row's source names, with the
// booking's id and nothing else, and the other host hears nothing — even
// when it is the one the app is signed in to. A host that answers as
// another installation, or cannot be reached, is refused before anything
// is sent; a host without the command is typed; the host's own refusal
// comes through unchanged. View reads the booking again with the strict
// page, narrowed to its workspace and start, and a booking the host no
// longer lists is gone.
import 'dart:convert';

import 'package:deskilo/core/backend/connection_outcome.dart';
import 'package:deskilo/core/backend/context_clients.dart';
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/codes/pg_code.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/reservations/data/host_my_reservation_actions.dart';
import 'package:deskilo/features/reservations/data/host_my_reservations_repository.dart';
import 'package:deskilo/features/reservations/domain/my_reservations.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/reservation_refusal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _selected = MyReservationsSource(installationId: 'inst-a', workspaceIds: ['ws-a'], hostedHere: true);
const _row = MyReservationsSource(installationId: 'inst-b', workspaceIds: ['ws-b']);

final _item = MyReservationItem(
  id: 'r-b1',
  workspaceId: 'ws-b',
  workspaceName: 'Leipzig',
  placeKind: MyReservationPlaceKind.seat,
  placeId: 'seat-1',
  placeLabel: 'B1',
  startsAt: DateTime.utc(2031, 3, 2, 8),
  endsAt: DateTime.utc(2031, 3, 2, 12),
  status: ReservationStatus.reserved,
  checkedInAt: null,
  checkedOutAt: null,
);

Map<String, Object?> _wire(String id, {String status = 'reserved'}) => {
      'id': id,
      'workspace_id': 'ws-b',
      'workspace_name': 'Leipzig',
      'place_kind': 'seat',
      'place_id': 'seat-1',
      'place_label': 'B1',
      'starts_at': '2031-03-02T08:00:00+00:00',
      'ends_at': '2031-03-02T12:00:00+00:00',
      'status': status,
      'checked_in_at': null,
      'checked_out_at': null,
    };

/// One host: what it was asked, and what it answers.
class _Host {
  final List<(String, Map<String, dynamic>)> received = [];
  ({int status, String code, String message, Object? details})? refusal;

  /// An answer that is not PostgREST's: a gateway's error page, a body that cannot be read.
  ({int status, String body})? raw;
  List<Map<String, Object?>> items = [_wire('r-b1', status: 'cancelled')];

  late final SupabaseClient client = SupabaseClient(
    'http://127.0.0.1:54321',
    'sb_publishable_test',
    httpClient: MockClient(_handle),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  http.Response _json(Object? body, int status, http.Request request) => http.Response(
        jsonEncode(body),
        status,
        request: request,
        headers: {'content-type': 'application/json'},
      );

  Future<http.Response> _handle(http.Request request) async {
    if (request.url.path == '/rest/v1/workspaces') {
      return _json([{'id': 'ws-b', 'timezone': 'Europe/Berlin'}], 200, request);
    }
    final name = request.url.pathSegments.last;
    received.add((name, jsonDecode(request.body) as Map<String, dynamic>));
    final r = refusal;
    final w = raw;
    if (w != null && name != 'my_reservations_page_v1') {
      return http.Response(w.body, w.status, request: request, headers: {'content-type': 'text/html'});
    }
    if (r != null && name != 'my_reservations_page_v1') {
      return _json({'code': r.code, 'message': r.message, 'details': r.details, 'hint': null}, r.status, request);
    }
    if (name == 'my_reservations_page_v1') {
      return _json({'schema_version': 1, 'items': items, 'has_more': false, 'next': null}, 200, request);
    }
    return _json(null, 200, request);
  }
}

void main() {
  late _Host a;
  late _Host b;
  late List<MyReservationsSource> resolved;

  Future<ResolvedWorkspaceHost> hostOf(MyReservationsSource source) async {
    resolved.add(source);
    final host = source.installationId == 'inst-a' ? a : b;
    return ResolvedWorkspaceHost(
      installationId: source.installationId,
      client: host.client,
      localUserId: 'local-${source.installationId}',
    );
  }

  HostMyReservationActions actions({Future<ResolvedWorkspaceHost> Function(MyReservationsSource)? resolve}) {
    final of = resolve ?? hostOf;
    return HostMyReservationActions(
      pages: HostMyReservationsRepository(
        platformSettings: () async => SettingsSet.defaults(const []),
        hostOf: of,
      ),
      hostOf: of,
    );
  }

  setUp(() {
    a = _Host();
    b = _Host();
    resolved = [];
  });

  test('Cancel leaves on the row\'s own host with its id; the selected host hears nothing', () async {
    await actions().cancel(_row, _item);
    expect(resolved, [_row]);
    expect(b.received.map((r) => r.$1), ['cancel_reservation']);
    expect(b.received.single.$2, {'p_reservation_id': 'r-b1'});
    expect(a.received, isEmpty, reason: 'inst-a is the signed-in, selected one: never asked');
    expect(resolved.contains(_selected), isFalse);
  });

  test('Check in leaves on the row\'s own host with its id', () async {
    await actions().checkIn(_row, _item);
    expect(b.received.map((r) => r.$1), ['check_in_reservation']);
    expect(b.received.single.$2, {'p_reservation_id': 'r-b1'});
    expect(a.received, isEmpty);
  });

  test('a host that answers as another installation is refused before anything is sent', () async {
    await expectLater(
      actions(resolve: (source) async => ResolvedWorkspaceHost(
            installationId: 'inst-a',
            client: a.client,
            localUserId: 'local-a',
          )).cancel(_row, _item),
      throwsA(isA<MyReservationsRefused>()
          .having((e) => e.failure, 'failure', MyReservationsFailure.hostUnavailable)),
    );
    expect(a.received, isEmpty);
    expect(b.received, isEmpty);
  });

  test('a host not connected here is the same typed refusal', () async {
    await expectLater(
      actions(resolve: (_) async => throw ConnectionFailure('inst-b', ConnectionFailureReason.notConnected))
          .checkIn(_row, _item),
      throwsA(isA<MyReservationsRefused>()
          .having((e) => e.failure, 'failure', MyReservationsFailure.hostUnavailable)),
    );
  });

  test('a host without the command is unsupported', () async {
    b.refusal = (status: 404, code: PgCode.pgrstFunctionNotFound, message: 'Could not find the function', details: null);
    await expectLater(
      actions().cancel(_row, _item),
      throwsA(isA<MyReservationsRefused>()
          .having((e) => e.failure, 'failure', MyReservationsFailure.unsupported)),
    );
    expect(a.received, isEmpty);
  });

  // #4315 — the host's own refusal reaches the card as the typed refusal, through the one
  // conversion of the booking writes, with its values read; never as the transport's error.
  test('a coded refusal of check-in or cancel is the typed refusal, its detail value read', () async {
    b.refusal = (status: 400, code: 'DKK17', message: 'check-in is not open yet', details: '{"minutes": 45}');
    for (final run in [() => actions().checkIn(_row, _item), () => actions().cancel(_row, _item)]) {
      await expectLater(
        run(),
        throwsA(isA<ReservationRefused>()
            .having((e) => e.refusal.kind, 'kind', ReservationRefusalKind.coded)
            .having((e) => e.refusal.code, 'code', DkCode.dkk17)
            .having((e) => e.refusal.minutes, 'minutes', 45)),
      );
    }
    b.refusal = (status: 400, code: DkCode.dkk18, message: 'x', details: null);
    await expectLater(
      actions().checkIn(_row, _item),
      throwsA(isA<ReservationRefused>().having((e) => e.refusal.code, 'code', DkCode.dkk18)),
    );
  });

  test('a code of no meaning keeps nothing of the host: an unknown refusal, still typed', () async {
    b.refusal = (status: 400, code: PgCode.raiseException, message: 'not cancellable', details: null);
    await expectLater(
      actions().cancel(_row, _item),
      throwsA(isA<ReservationRefused>()
          .having((e) => e.refusal.kind, 'kind', ReservationRefusalKind.unknown)),
    );
  });

  test('a gateway answer or a body that cannot be read is NOT a refusal: it stays the transport\'s error', () async {
    for (final answer in [(status: 502, body: '<html>bad gateway</html>'), (status: 200, body: '{"truncated"')]) {
      b.raw = answer;
      await expectLater(
        actions().checkIn(_row, _item),
        throwsA(isA<PostgrestException>().having((e) => e, 'not typed', isNot(isA<ReservationRefused>()))),
        reason: '${answer.status}',
      );
    }
  });

  test('View reads the booking again on its host, narrowed to its workspace and start', () async {
    final fresh = await actions().view(_row, _item);
    expect(fresh.status, ReservationStatus.cancelled);
    final (name, params) = b.received.single;
    expect(name, 'my_reservations_page_v1');
    expect(params['p_workspace_id'], 'ws-b');
    expect(params['p_from'], '2031-03-02T08:00:00.000Z');
    expect(params['p_to'], '2031-03-02T08:00:01.000Z');
    expect(a.received, isEmpty);
  });

  test('a booking its host no longer lists there is gone', () async {
    b.items = [_wire('someone-else')];
    await expectLater(
      actions().view(_row, _item),
      throwsA(isA<MyReservationsRefused>().having((e) => e.failure, 'failure', MyReservationsFailure.gone)),
    );
  });
}
