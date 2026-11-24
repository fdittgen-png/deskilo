// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4159 (v2.2) -- the production booking adapter and the booking recovery
// over signed HTTP, against the replayed database of the topology job: the
// RPC names, argument shapes, PostgREST JSON and authenticated semantics the
// app really meets, not a Dart map answering for a server
// (test/features/reservations/booking_recovery_http_test.dart keeps that
// faster layer).
//
// Every call is made as an ordinary member (the anon key and a password
// session) through SupabaseReservationRepository and BookingRecovery; the
// service key only reads back. The seed (scripts/topology_stacks.sh,
// seed_booking) gives W-A and W-B the SAME local workspace and seat ids, so a
// write that lands on the wrong host shows. Expected facts are written down
// from that seed: the own seat's 10:00 of day five is N's, the rented seat is
// visible to M alone; each scenario books on a day of its own. Runs only with DESKILO_TOPOLOGY_FILE; the CI
// invocation requires its scenarios by name (quality.yml).
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/core/storage/booking_intent_store.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/reservations/application/book_seat.dart'
    show BookingRequest;
import 'package:deskilo/features/reservations/application/booking_recovery.dart';
import 'package:deskilo/features/reservations/data/supabase_reservation_repository.dart';
import 'package:deskilo/features/reservations/domain/booking_intent.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/reservation_refusal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

final _file = Platform.environment['DESKILO_TOPOLOGY_FILE'];

/// The wire between the app and its host: everything is forwarded to the real
/// server; while [dropAnswers] is set, a booking request is forwarded and
/// COMMITS there, and its answer is then lost before the app reads it.
class _Wire extends http.BaseClient {
  _Wire(this._inner);

  final http.Client _inner;
  bool dropAnswers = false;
  final List<String> bookingRequestIds = [];
  int answersDropped = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isBooking = request.url.path.endsWith('/rpc/create_reservation_once');
    if (isBooking && request is http.Request) {
      bookingRequestIds.add(
        (jsonDecode(request.body) as Map)['p_client_request_id'] as String,
      );
    }
    final response = await _inner.send(request);
    if (isBooking && dropAnswers) {
      await response.stream.drain<void>();
      answersDropped++;
      throw http.ClientException('connection closed before the answer');
    }
    return response;
  }
}

/// One signed-in account on one host, with the production adapter on it.
class _Session {
  _Session(this.client, this.wire, this.userId, String origin)
    : repository = SupabaseReservationRepository(client, InMemoryCacheStore()),
      scope = BookingIntentScope(account: userId, origin: origin) {
    recovery = BookingRecovery(
      reservations: repository,
      store: InMemoryBookingIntentStore(),
      scope: scope,
      clock: const SystemClock(),
      schemaVersion: 1,
    );
  }

  final SupabaseClient client;
  final _Wire wire;
  final String userId;
  final SupabaseReservationRepository repository;
  final BookingIntentScope scope;
  late final BookingRecovery recovery;
}

/// The server's rows, read with its service key (never the app's path).
class _Readback {
  _Readback(String url, String service)
    : _client = SupabaseClient(url, service, httpClient: http.Client());

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> reservations(String workspaceId) async =>
      (await _client
              .from('reservations')
              .select('id, member_id, seat_id, starts_at, ends_at, status')
              .eq('workspace_id', workspaceId))
          .cast<Map<String, dynamic>>();

  Future<int> claims(String workspaceId) async =>
      (await _client
              .from('reservation_requests')
              .select('client_request_id')
              .eq('workspace_id', workspaceId))
          .length;
}

void main() {
  if (_file == null) {
    test(
      'booking over signed HTTP',
      () {},
      skip: 'needs the stacks of the database job; set DESKILO_TOPOLOGY_FILE',
    );
    return;
  }

  late String ws;
  late String seat;
  late String rented;
  late List<DateTime> starts; // local 10:00 of days 1..5 at W-A, UTC
  late List<DateTime> startsB; // the same at W-B
  late String memberId;
  late String otherMemberId;
  late _Session member; // M at W-A
  late _Session other; // N at W-A: a member who does not see the rented room
  late _Session stranger; // a W-A account that is no member of the workspace
  late _Session
  memberB; // M's counterpart at W-B (another host, same local ids)
  late BookingIntent lostIntent; // the intent of the lost-answer booking
  late _Readback wa;
  late _Readback wb;
  late _Readback p;

  Future<_Session> signIn(
    Map<String, dynamic> stack,
    Map<String, dynamic> who,
    String password,
  ) async {
    final wire = _Wire(http.Client());
    final client = SupabaseClient(
      stack['url'] as String,
      stack['anon'] as String,
      httpClient: wire,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final session = await client.auth.signInWithPassword(
      email: who['email'] as String,
      password: password,
    );
    expect(session.user?.id, who['id'], reason: 'the seeded account');
    return _Session(client, wire, who['id'] as String, stack['url'] as String);
  }

  DateTime end(DateTime start) => start.add(const Duration(hours: 1));

  BookingRequest request(DateTime start, {String? seatId}) => (
    workspaceId: ws,
    seatId: seatId ?? seat,
    start: start,
    end: end(start),
    checkIn: false,
    forMemberId: null,
    pattern: null,
    until: null,
  );

  /// What a refusal of [attempt] is, as the application reads it.
  Future<ReservationRefusal> refusalOf(Future<Object?> attempt) async {
    try {
      await attempt;
    } on ReservationRefused catch (e) {
      return e.refusal;
    }
    fail('the booking was accepted');
  }

  Future<int> bookingsAt(_Readback host, String seatId, DateTime start) async =>
      (await host.reservations(ws))
          .where(
            (r) =>
                r['seat_id'] == seatId &&
                DateTime.parse(r['starts_at'] as String)
                    .isAtSameMomentAs(start),
          )
          .length;

  setUpAll(() async {
    // flutter_test replaces the HTTP client with one that answers 400.
    HttpOverrides.global = null;
    final d =
        jsonDecode(File(_file!).readAsStringSync()) as Map<String, dynamic>;
    final password = d['password'] as String;
    final a = d['wa'] as Map<String, dynamic>;
    final b = d['wb'] as Map<String, dynamic>;
    final pp = d['p'] as Map<String, dynamic>;
    final fa = a['booking'] as Map<String, dynamic>;
    final fb = b['booking'] as Map<String, dynamic>;
    expect(fa['workspaceId'], fb['workspaceId'], reason: 'equal local ids');
    expect(fa['seatId'], fb['seatId'], reason: 'equal local seat ids');
    ws = fa['workspaceId'] as String;
    seat = fa['seatId'] as String;
    rented = fa['rentedSeatId'] as String;
    List<DateTime> days(Map<String, dynamic> f) => [
      for (final s in (f['starts'] as String).split('|')) DateTime.parse(s),
    ];
    starts = days(fa);
    startsB = days(fb);
    expect(starts, hasLength(5));
    expect(startsB, hasLength(5));
    memberId = fa['memberId'] as String;
    otherMemberId = fa['otherMemberId'] as String;
    member = await signIn(a, fa['member'] as Map<String, dynamic>, password);
    other = await signIn(a, fa['other'] as Map<String, dynamic>, password);
    stranger = await signIn(a, a['stranger'] as Map<String, dynamic>, password);
    memberB = await signIn(b, fb['member'] as Map<String, dynamic>, password);
    wa = _Readback(a['url'] as String, a['service'] as String);
    wb = _Readback(b['url'] as String, b['service'] as String);
    p = _Readback(pp['url'] as String, pp['service'] as String);
  });

  test('a booking is accepted and read back: the id, the member, the seat and '
      'the UTC window agree with the database', () async {
    final booked = await member.recovery.book(request(starts[0]));
    final stored = (await wa.reservations(ws))
        .singleWhere((r) => r['id'] == booked.reservationId);
    expect(stored['seat_id'], seat);
    expect(stored['member_id'], memberId);
    expect(stored['status'], 'reserved');
    expect(DateTime.parse(stored['starts_at'] as String), starts[0]);
    expect(DateTime.parse(stored['ends_at'] as String), end(starts[0]));
    final read = await member.repository.fetchById(booked.reservationId);
    expect(read, isNotNull, reason: 'the member reads their own booking');
    expect(read!.startsAt.toUtc(), starts[0]);
    expect(read.endsAt.toUtc(), end(starts[0]));
    expect(read.status, ReservationStatus.reserved);
    expect(await member.recovery.unresolved(), isEmpty);
  });

  test('the same client request id replays to the same reservation and '
      'commits one', () async {
    const id = '00000000-0000-4000-8000-0000004159b1';
    final first = await member.repository.create(
      workspaceId: ws,
      seatId: seat,
      startsAt: starts[1],
      endsAt: end(starts[1]),
      requestId: id,
    );
    final again = await member.repository.create(
      workspaceId: ws,
      seatId: seat,
      startsAt: starts[1],
      endsAt: end(starts[1]),
      requestId: id,
    );
    expect(again, first, reason: 'the replay answers the original booking');
    expect(await bookingsAt(wa, seat, starts[1]), 1);
    final outcome = await member.repository.requestOutcome(ws, id);
    expect(outcome.status, RequestOutcomeStatus.committed);
    expect(outcome.reservationId, first);
  });

  test('a booking committed with its answer lost is unknown, then recovered '
      'once: one database reservation, the original request id', () async {
    member.wire
      ..dropAnswers = true
      ..answersDropped = 0
      ..bookingRequestIds.clear();
    BookingOutcomeUnknown? unknown;
    try {
      await member.recovery.book(request(starts[2]));
    } on BookingOutcomeUnknown catch (e) {
      unknown = e;
    }
    member.wire.dropAnswers = false;
    expect(
      unknown,
      isNotNull,
      reason: 'a lost answer is unknown, never refused',
    );
    expect(member.wire.answersDropped, greaterThan(0));
    final requestId = unknown!.intent.requestId;
    expect(member.wire.bookingRequestIds.toSet(), {
      requestId,
    }, reason: 'every attempt carried the one id');
    expect(
      await bookingsAt(wa, seat, starts[2]),
      1,
      reason: 'the database committed it although nobody was told',
    );
    final open = await member.recovery.unresolved();
    expect(open.map((i) => i.requestId), [requestId]);

    lostIntent = open.single;
    final check = await member.recovery.check(open.single);
    expect(check, isA<RecoveryCommitted>());
    final committed = (check as RecoveryCommitted).reservationId;
    expect(await member.recovery.unresolved(), isEmpty);
    final replay = await member.recovery.resume(open.single);
    expect(replay.reservationId, committed, reason: 'the same reservation');
    expect(await bookingsAt(wa, seat, starts[2]), 1, reason: 'still one');
  });

  test('a seat held by someone else is refused as a typed refusal, nothing '
      'is booked and nothing stays open', () async {
    final refusal = await refusalOf(member.recovery.book(request(starts[4])));
    expect(refusal.blockedByOther, isTrue);
    expect(refusal.kind, isNot(ReservationRefusalKind.coded));
    expect(await bookingsAt(wa, seat, starts[4]), 1, reason: "N's booking");
    expect(await member.recovery.unresolved(), isEmpty);
  });

  test('an account that is no member gets a coded refusal and books '
      'nothing', () async {
    final before = (await wa.reservations(ws)).length;
    final refusal = await refusalOf(stranger.recovery.book(request(starts[3])));
    expect(refusal.kind, ReservationRefusalKind.coded);
    expect(refusal.code, DkCode.dkk27, reason: 'not an active member');
    expect(await wa.reservations(ws), hasLength(before));
  });

  test('a seat the member may not see is refused exactly as one that does '
      'not exist, and the audience books it', () async {
    final hidden = await refusalOf(
      other.recovery.book(request(starts[3], seatId: rented)),
    );
    final unknown = await refusalOf(
      other.recovery.book(
        request(starts[3], seatId: '00000000-0000-4000-8000-000000415999'),
      ),
    );
    expect(hidden.kind, unknown.kind);
    expect(hidden.code, unknown.code);
    expect(hidden.blockedByOther, unknown.blockedByOther);
    expect(await bookingsAt(wa, rented, starts[3]), 0);

    // The positive control: the room's audience books the same seat and window.
    final booked = await member.recovery.book(
      request(starts[3], seatId: rented),
    );
    expect(await bookingsAt(wa, rented, starts[3]), 1);
    expect(
      (await wa.reservations(ws))
          .singleWhere((r) => r['id'] == booked.reservationId)['seat_id'],
      rented,
    );
  });

  test('a request outcome belongs to its creator: another member, a '
      'non-member and the other host learn nothing', () async {
    const id = '00000000-0000-4000-8000-0000004159b1'; // M's replay request
    final mine = await member.repository.requestOutcome(ws, id);
    expect(mine.status, RequestOutcomeStatus.committed);
    final theirs = await other.repository.requestOutcome(ws, id);
    expect(theirs.status, RequestOutcomeStatus.absent);
    expect(theirs.reservationId, isNull);
    // A non-member is refused outright; either way no foreign result leaks.
    try {
      final foreign = await stranger.repository.requestOutcome(ws, id);
      expect(foreign.reservationId, isNull);
    } on PostgrestException catch (e) {
      expect(e.message, contains('not an active member'));
    }
    // Another account's recovery will not even ask for M's intent, and the
    // server would answer it as absent.
    expect(await other.recovery.check(lostIntent), isA<RecoveryUnavailable>());
    final lostByOther = await other.repository.requestOutcome(
      ws,
      lostIntent.requestId,
    );
    expect(lostByOther.status, RequestOutcomeStatus.absent);
    final elsewhere = await memberB.repository.requestOutcome(ws, id);
    expect(elsewhere.status, RequestOutcomeStatus.absent);
    expect(elsewhere.reservationId, isNull);
  });

  test('the host that was targeted is the one written: W-B and P hold no '
      'booking of W-A, and the equal local ids stay apart', () async {
    final onA = await wa.reservations(ws);
    expect(onA.where((r) => r['member_id'] == memberId), isNotEmpty);
    // W-B holds only its own seed: N's window and nothing of M's.
    final onB = await wb.reservations(ws);
    expect(onB, hasLength(1), reason: 'only the fixture reservation of N');
    expect(onB.single['member_id'], otherMemberId);
    expect(await wb.claims(ws), 0, reason: 'no request claim reached W-B');
    expect(await p.reservations(ws), isEmpty, reason: 'P holds no booking');
    expect(await p.claims(ws), 0);
    // The same local seat on W-B is writable by its own member, on its own host.
    final bookedB = await memberB.recovery.book(request(startsB[0]));
    expect(
      (await wb.reservations(ws)).any((r) => r['id'] == bookedB.reservationId),
      isTrue,
    );
    expect(
      (await wa.reservations(ws)).any((r) => r['id'] == bookedB.reservationId),
      isFalse,
      reason: "W-B's booking is not on W-A",
    );
  });
}
