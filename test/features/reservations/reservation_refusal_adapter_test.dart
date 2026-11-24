// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4156 (A1 of #4174) — the real adapter. A raw PostgREST error answered over
// HTTP becomes the typed refusal at the reservation data boundary, with the
// transport's error kept as its cause and nothing of the backend's wording on
// the value a person's screen reads; a malformed DETAIL is a refusal with the
// value absent, not a second failure. A transport fault is NOT a refusal: it
// stays an unknown outcome under the booking's original request id, and the
// pending intent survives it.
import 'dart:convert';

import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/codes/pg_code.dart';
import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/core/storage/booking_intent_store.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/reservations/application/booking_recovery.dart';
import 'package:deskilo/features/reservations/data/supabase_reservation_repository.dart';
import 'package:deskilo/features/reservations/domain/booking_intent.dart';
import 'package:deskilo/features/reservations/presentation/booking_error_text.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _scope = BookingIntentScope(
  account: 'u-1',
  origin: 'http://127.0.0.1:54321',
);
final _now = DateTime.utc(2026, 10, 7, 8);
final _start = DateTime.utc(2026, 10, 7, 9);
final _end = DateTime.utc(2026, 10, 7, 13);

/// The error body PostgREST answers a raised exception with.
http.Response _postgrestError(
  http.Request request, {
  required String code,
  required String message,
  Object? details,
}) => http.Response(
  jsonEncode({
    'code': code,
    'message': message,
    'details': details,
    'hint': null,
  }),
  400,
  request: request,
  headers: {'content-type': 'application/json'},
);

SupabaseClient _client(Future<http.Response> Function(http.Request) handle) =>
    SupabaseClient(
      'http://127.0.0.1:54321',
      'sb_publishable_test',
      httpClient: MockClient(handle),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

Future<Object?> _caught(Future<Object?> Function() call) async {
  try {
    await call();
    return null;
  } on Object catch (e) {
    return e;
  }
}

Future<Object?> _create(SupabaseClient client) => _caught(
  () => SupabaseReservationRepository(client, InMemoryCacheStore()).create(
    workspaceId: 'ws-1',
    seatId: 'seat-1',
    startsAt: _start,
    endsAt: _end,
  ),
);

/// A booking confirmed through the recovery, the server answering with [handle]: the intent
/// ledger and what the caller was told, so a lost outcome is told from a refusal.
Future<({Object? told, List<BookingIntent> open, List<String> ids})> _booked(
  Future<http.Response> Function(http.Request) handle,
) async {
  final ids = <String>[];
  final recovery = BookingRecovery(
    reservations: SupabaseReservationRepository(
      _client((request) async {
        final params = jsonDecode(request.body) as Map<String, dynamic>;
        ids.add(params['p_client_request_id'] as String);
        return handle(request);
      }),
      InMemoryCacheStore(),
    ),
    store: InMemoryBookingIntentStore(),
    scope: _scope,
    clock: FixedClock(_now),
    schemaVersion: 377,
  );
  Object? told;
  try {
    await recovery.book((
      workspaceId: 'ws-1',
      seatId: 'seat-1',
      start: _start,
      end: _end,
      checkIn: false,
      forMemberId: null,
      pattern: null,
      until: null,
    ));
  } on Object catch (e) {
    told = e;
  }
  return (told: told, open: await recovery.unresolved(), ids: ids);
}

Future<Object?> _identify(SupabaseClient client) => _caught(
  () => SupabaseReservationRepository(client, InMemoryCacheStore()).kioskIdentify(
    workspaceId: 'ws-1',
    badgeToken: 'unknown-badge',
  ),
);

void main() {
  final en = AppLocalizationsEn();

  // #4316 — the kiosk's first and most frequent refusal reaches the screen typed.
  test('an unknown badge at kiosk_identify is the kiosk\'s own refusal, never the transport\'s '
      'error', () async {
    final error = await _identify(
      _client((r) async => _postgrestError(r, code: PgCode.raiseException, message: 'badge not recognized')),
    );
    expect(error, isA<ReservationRefused>());
    expect((error! as ReservationRefused).refusal.kind, ReservationRefusalKind.badgeRejected);
  });

  test('a transport fault at kiosk_identify is not a refusal', () async {
    final error = await _identify(
      _client((r) async => throw http.ClientException('connection closed before the answer')),
    );
    expect(error, isNot(isA<ReservationRefused>()));
    expect(error, isNotNull);
  });

  // #4317 — an answer that is not a PostgREST refusal leaves the outcome unknown.
  group('a booking whose answer is not PostgREST\'s is an unknown outcome, never a refusal', () {
    final answers = <String, Future<http.Response> Function(http.Request)>{
      'a 504 with an HTML body after the commit': (r) async =>
          http.Response('<html><body>504 Gateway Time-out</body></html>', 504, request: r),
      'a 503 before the commit': (r) async => http.Response('upstream unavailable', 503, request: r),
      'a 200 with a truncated body': (r) async =>
          http.Response('{"id": "res-', 200, request: r, headers: {'content-type': 'application/json'}),
    };
    for (final entry in answers.entries) {
      test(entry.key, () async {
        final out = await _booked(entry.value);
        expect(out.told, isA<BookingOutcomeUnknown>(), reason: 'told: ${out.told}');
        expect(out.open, hasLength(1), reason: 'the intent stays for the recovery');
        expect(out.ids.toSet(), hasLength(1), reason: 'one request id');
        expect(out.open.single.requestId, out.ids.first);
      });
    }

    test('a refusal the database raised stays definitive, with no intent left', () async {
      final out = await _booked(
        (r) async => _postgrestError(r, code: DkCode.dkk19, message: 'you already have a reservation in that period'),
      );
      expect(out.told, isA<ReservationRefused>());
      expect(out.open, isEmpty);
    });
  });


  test('a raw PostgREST refusal becomes the typed refusal, its values '
      'read, its error kept as the cause', () async {
    final error = await _create(
      _client(
        (r) async => _postgrestError(
          r,
          code: DkCode.dkk06,
          message: 'booking slots must be a multiple of the grid',
          details: '{"minutes": 20}',
        ),
      ),
    );
    expect(error, isA<ReservationRefused>());
    final refused = error! as ReservationRefused;
    expect(refused.refusal.kind, ReservationRefusalKind.coded);
    expect(refused.refusal.code, DkCode.dkk06);
    expect(refused.refusal.minutes, 20);
    expect(
      refused.cause,
      isA<PostgrestException>().having((e) => e.code, 'code', DkCode.dkk06),
      reason: 'the original error stays for the trace',
    );
    expect(
      bookingErrorText(en, refused, 'fallback'),
      en.planSlotError(20),
      reason: 'the words are chosen by the presentation, from the typed value',
    );
  });

  test('valid JSON whose number is not a number is a refusal with the value '
      'absent, never a second exception', () async {
    for (final details in [
      '{"minutes": "20"}',
      '{"minutes": [20]}',
      '{"minutes": {"x": 20}}',
      '{"minutes": true}',
      '{"minutes": null}',
      '[1, 2]',
      '"just text"',
      'not json at all',
    ]) {
      final error = await _create(
        _client(
          (r) async => _postgrestError(
            r,
            code: DkCode.dkk06,
            message: 'booking slots must be a multiple of the grid',
            details: details,
          ),
        ),
      );
      expect(error, isA<ReservationRefused>(), reason: details);
      expect(
        (error! as ReservationRefused).refusal.minutes,
        isNull,
        reason: details,
      );
      expect(
        bookingErrorText(en, error, 'fallback', stepMinutes: 30),
        en.planSlotError(30),
        reason: '$details: the screen\'s own grid',
      );
    }
  });

  test('an unknown code keeps nothing of the backend: the fallback is shown, '
      'no sentence leaks', () async {
    final error = await _create(
      _client(
        (r) async => _postgrestError(
          r,
          code: 'XX000',
          message: 'relation "reservations" violates constraint r_excl',
        ),
      ),
    );
    final refused = error! as ReservationRefused;
    expect(refused.refusal.kind, ReservationRefusalKind.unknown);
    expect(refused.refusal.code, isNull);
    expect(refused.toString(), isNot(contains('relation')));
    expect(bookingErrorText(en, refused, 'fallback'), 'fallback');
  });

  test('a transport fault is not a refusal: it stays an unknown outcome under '
      'the original request id, and the intent survives', () async {
    final ids = <String>[];
    final recovery = BookingRecovery(
      reservations: SupabaseReservationRepository(
        _client((request) async {
          final params = jsonDecode(request.body) as Map<String, dynamic>;
          ids.add(params['p_client_request_id'] as String);
          throw http.ClientException('connection closed before the answer');
        }),
        InMemoryCacheStore(),
      ),
      store: InMemoryBookingIntentStore(),
      scope: _scope,
      clock: FixedClock(_now),
      schemaVersion: 377,
    );
    BookingOutcomeUnknown? unknown;
    Object? other;
    try {
      await recovery.book((
        workspaceId: 'ws-1',
        seatId: 'seat-1',
        start: _start,
        end: _end,
        checkIn: false,
        forMemberId: null,
        pattern: null,
        until: null,
      ));
    } on BookingOutcomeUnknown catch (e) {
      unknown = e;
    } on Object catch (e) {
      other = e;
    }
    expect(other, isNull, reason: 'never a refusal, never an exception');
    expect(unknown, isNotNull);
    expect(ids.toSet(), hasLength(1), reason: 'one request id on every try');
    final open = await recovery.unresolved();
    expect(open, hasLength(1), reason: 'the pending intent was not deleted');
    expect(open.single.requestId, ids.first);
    expect(open.single.requestId, unknown!.intent.requestId);
  });

  test('a refusal after the retry is a definitive refusal: no pending intent '
      'is left to resume', () async {
    final recovery = BookingRecovery(
      reservations: SupabaseReservationRepository(
        _client(
          (r) async => _postgrestError(
            r,
            code: DkCode.dkk19,
            message: 'you already have a reservation in that period',
          ),
        ),
        InMemoryCacheStore(),
      ),
      store: InMemoryBookingIntentStore(),
      scope: _scope,
      clock: FixedClock(_now),
      schemaVersion: 377,
    );
    Object? error;
    try {
      await recovery.book((
        workspaceId: 'ws-1',
        seatId: 'seat-1',
        start: _start,
        end: _end,
        checkIn: false,
        forMemberId: null,
        pattern: null,
        until: null,
      ));
    } on Object catch (e) {
      error = e;
    }
    expect(error, isA<ReservationRefused>());
    expect(
      (error! as ReservationRefused).refusal.code,
      DkCode.dkk19,
      reason: 'the person reads the typed refusal',
    );
    expect(await recovery.unresolved(), isEmpty);
  });
}
