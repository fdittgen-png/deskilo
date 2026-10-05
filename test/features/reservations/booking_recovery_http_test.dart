// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1855 B — the interrupted booking over the real HTTP path. The server
// commits request R, every answer is lost on the wire, the person is told
// the outcome is unknown; the original id is then asked for through the
// protected own-result lookup and the SAME request is replayed. Exactly one
// booking exists at the end, whatever the app did in between, and the
// replay carries the original id and payload, never a fresh request.
import 'dart:convert';

import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/core/storage/booking_intent_store.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/reservations/application/booking_recovery.dart';
import 'package:deskilo/features/reservations/data/supabase_reservation_repository.dart';
import 'package:deskilo/features/reservations/domain/booking_intent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _scope = BookingIntentScope(account: 'u-1', origin: 'http://127.0.0.1:54321');
final _now = DateTime.utc(2026, 10, 7, 8);

/// A tiny server: it books once per request id and can drop its answers.
class _Server {
  final Map<String, String> bookings = {}; // request id -> reservation id
  final List<Map<String, dynamic>> received = [];
  bool dropAnswers = false;

  http.Response _json(http.Request request, Object? body) => http.Response(
        jsonEncode(body),
        200,
        request: request, // postgrest reads the request back off the answer
        headers: {'content-type': 'application/json'},
      );

  Future<http.Response> handle(http.Request request) async {
    final params = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    switch (request.url.path) {
      case '/rest/v1/rpc/create_reservation_once':
        received.add(params);
        final id = params['p_client_request_id'] as String;
        final reservation = bookings.putIfAbsent(id, () => 'res-${bookings.length + 1}');
        if (dropAnswers) {
          throw http.ClientException('connection closed before the answer');
        }
        return _json(request, reservation);
      case '/rest/v1/rpc/reservation_request_outcome':
        final id = params['p_client_request_id'] as String;
        return bookings.containsKey(id)
            ? _json(request, {'status': 'committed', 'reservation_id': bookings[id]})
            : _json(request, {'status': 'absent', 'retention_days': 90});
      default:
        fail('unexpected endpoint ${request.url.path}');
    }
  }
}

void main() {
  test('commit, every answer lost, outcome unknown, checked and replayed: '
      'one booking, the original id and payload', () async {
    final server = _Server();
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'sb_publishable_test',
      httpClient: MockClient(server.handle),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final recovery = BookingRecovery(
      reservations: SupabaseReservationRepository(client, InMemoryCacheStore()),
      store: InMemoryBookingIntentStore(),
      scope: _scope,
      clock: FixedClock(_now),
      schemaVersion: 377,
    );
    final request = (
      workspaceId: 'ws-1',
      seatId: 'seat-1',
      start: DateTime.utc(2026, 10, 7, 9),
      end: DateTime.utc(2026, 10, 7, 13),
      checkIn: false,
      forMemberId: null,
      pattern: null,
      until: null,
    );

    server.dropAnswers = true;
    BookingOutcomeUnknown? unknown;
    try {
      await recovery.book(request);
    } on BookingOutcomeUnknown catch (e) {
      unknown = e;
    }
    expect(unknown, isNotNull, reason: 'a lost answer is unknown, never "failed"');
    expect(server.bookings, hasLength(1), reason: 'the server did commit it');
    final open = await recovery.unresolved();
    expect(open, hasLength(1));
    expect(open.single.requestId, unknown!.intent.requestId);

    // The network is back: ask by the original id.
    server.dropAnswers = false;
    final check = await recovery.check(open.single);
    expect(check, isA<RecoveryCommitted>());
    expect((check as RecoveryCommitted).reservationId, 'res-1');
    expect(await recovery.unresolved(), isEmpty, reason: 'settled by the answer');

    // And a replay (a second device tap, a refresh) is the SAME request.
    final again = await recovery.resume(open.single);
    expect(again.reservationId, 'res-1');
    expect(server.bookings, hasLength(1), reason: 'never a second booking');
    final ids = {for (final r in server.received) r['p_client_request_id']};
    expect(ids, {open.single.requestId}, reason: 'one id on every attempt');
    expect({for (final r in server.received) r['p_workspace_id']}, {'ws-1'});
  });

  test('an unreadable store at start-up shows nothing and crashes nothing', () async {
    final store = InMemoryBookingIntentStore()..failReads = true;
    final recovery = BookingRecovery(
      reservations: SupabaseReservationRepository(
        SupabaseClient('http://127.0.0.1:54321', 'k',
            httpClient: MockClient((r) async => fail('no request expected'))),
        InMemoryCacheStore(),
      ),
      store: store,
      scope: _scope,
      clock: FixedClock(_now),
      schemaVersion: 377,
    );
    expect(await recovery.unresolved(), isEmpty);
  });

  test('the replay after a workspace switch still goes to the original one', () async {
    final server = _Server();
    final client = SupabaseClient('http://127.0.0.1:54321', 'k',
        httpClient: MockClient(server.handle),
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    final recovery = BookingRecovery(
      reservations: SupabaseReservationRepository(client, InMemoryCacheStore()),
      store: InMemoryBookingIntentStore(),
      scope: _scope,
      clock: FixedClock(_now),
      schemaVersion: 377,
    );
    server.dropAnswers = true;
    BookingIntent? intent;
    try {
      await recovery.book((
        workspaceId: 'ws-A',
        seatId: 'seat-1',
        start: DateTime.utc(2026, 10, 7, 9),
        end: DateTime.utc(2026, 10, 7, 13),
        checkIn: false,
        forMemberId: null,
        pattern: null,
        until: null,
      ));
    } on BookingOutcomeUnknown catch (e) {
      intent = e.intent;
    }
    // The person has since opened workspace B; the replay does not follow them.
    server.dropAnswers = false;
    await recovery.resume(intent!);
    expect({for (final r in server.received) r['p_workspace_id']}, {'ws-A'});
  });
}
