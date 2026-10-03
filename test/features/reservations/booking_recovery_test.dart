// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1855 — the interrupted booking keeps its original intent. The server
// commits, the answer is lost, the app restarts: the one booking is found
// by its original request id, and a resume replays that request rather
// than making a second one. A device that cannot persist sends nothing;
// a bookkeeping failure after a known commit changes no answer; a known
// refusal closes the intent; intents never leave their account and
// server. The negative control books with a FRESH id and must show the
// duplicate the rule exists to prevent.
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/core/storage/booking_intent_store.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/reservations/application/book_seat.dart';
import 'package:deskilo/features/reservations/application/booking_recovery.dart';
import 'package:deskilo/features/reservations/domain/booking_intent.dart';
import 'package:flutter_test/flutter_test.dart';

const _scope = BookingIntentScope(account: 'u-1', origin: 'https://a.test');
const _other = BookingIntentScope(account: 'u-2', origin: 'https://a.test');
final _now = DateTime.utc(2026, 10, 7, 8);

BookingRequest _request({DateTime? start}) => (
  workspaceId: 'ws-1',
  seatId: 'seat-1',
  start: start ?? DateTime.utc(2026, 10, 7, 9),
  end: (start ?? DateTime.utc(2026, 10, 7, 9)).add(const Duration(hours: 4)),
  checkIn: false,
  forMemberId: null,
  pattern: null,
  until: null,
);

BookingRecovery _recovery(
  FakeReservationRepository repo,
  InMemoryBookingIntentStore store, {
  BookingIntentScope scope = _scope,
  DateTime? now,
}) => BookingRecovery(
  reservations: repo,
  store: store,
  scope: scope,
  clock: FixedClock(now ?? _now),
  schemaVersion: 350,
);

FakeReservationRepository _repo() {
  final repo = FakeReservationRepository(myMemberId: 'member-1');
  repo.allowPastBookings = true;
  return repo;
}

void main() {
  group('the regression: commit, lost answer, restart', () {
    test(
      'the one booking is found by the original id and never remade',
      () async {
        final repo = _repo()..failNextCreateTransport = true;
        final store = InMemoryBookingIntentStore();

        // The send books; the answer is lost.
        await expectLater(
          _recovery(repo, store).book(_request()),
          throwsA(isA<BookingOutcomeUnknown>()),
        );
        expect(repo.reservations, hasLength(1), reason: 'the server committed');
        final ledger = BookingIntentLedger.decode(store.value);
        expect(ledger.intents.single.status, BookingIntentStatus.unknown);
        final requestId = ledger.intents.single.requestId;

        // "Restart": a new command over the SAME reopened store.
        final later = _recovery(
          repo,
          store,
          now: _now.add(const Duration(hours: 1)),
        );
        final open = await later.unresolved(workspaceId: 'ws-1');
        expect(open.map((i) => i.requestId), [requestId]);

        // Check: the server says committed, by the original id.
        final check = await later.check(open.single);
        expect(check, isA<RecoveryCommitted>());
        expect(
          (check as RecoveryCommitted).reservationId,
          repo.reservations.single.id,
        );
        expect(
          await later.unresolved(workspaceId: 'ws-1'),
          isEmpty,
          reason: 'a known commit settles the intent',
        );
        expect(repo.reservations, hasLength(1));
      },
    );

    test(
      'resume replays the original request: one booking, the same id',
      () async {
        final repo = _repo()..failNextCreateTransport = true;
        final store = InMemoryBookingIntentStore();
        await expectLater(
          _recovery(repo, store).book(_request()),
          throwsA(isA<BookingOutcomeUnknown>()),
        );
        final intent = (await _recovery(repo, store).unresolved()).single;

        final booked = await _recovery(repo, store).resume(intent);
        expect(booked.reservationId, repo.reservations.single.id);
        expect(repo.reservations, hasLength(1), reason: 'no second booking');
        expect(repo.createCalls, 2, reason: 'the server was asked twice');
        expect(await _recovery(repo, store).unresolved(), isEmpty);
      },
    );

    test(
      'NEGATIVE CONTROL — a retry with a fresh id hides the booking it made',
      () async {
        final repo = _repo()..failNextCreateTransport = true;
        final request = _request();
        await expectLater(
          repo.create(
            workspaceId: request.workspaceId,
            seatId: request.seatId,
            startsAt: request.start,
            endsAt: request.end,
          ),
          throwsA(anything),
        );
        expect(repo.reservations, hasLength(1), reason: 'the server committed');
        // What the app did before #1855: a new call under a NEW id. The
        // server's exclusion refuses it — so the member is told "refused"
        // about a booking that exists, and has no way to find it.
        await expectLater(
          repo.create(
            workspaceId: request.workspaceId,
            seatId: request.seatId,
            startsAt: request.start,
            endsAt: request.end,
          ),
          throwsA(
            predicate(
              (e) =>
                  '$e'.contains('conflict') ||
                  '$e'.contains('already have a reservation'),
            ),
          ),
        );
        // A seat nobody holds, same fresh-id habit: a second booking.
        await repo.create(
          workspaceId: request.workspaceId,
          seatId: 'seat-2',
          startsAt: request.start.add(const Duration(days: 1)),
          endsAt: request.end.add(const Duration(days: 1)),
        );
        expect(
          repo.outcomeCalls,
          0,
          reason: 'nothing ever asked by the original id',
        );
      },
    );
  });

  group('the intent is bound to its payload and its scope', () {
    test('a pending intent older than the grace reads as unknown', () async {
      final store = InMemoryBookingIntentStore();
      final repo = _repo();
      // A save that was never followed by a send (the app died in between).
      final intent = BookingIntent(
        requestId: 'r-pending',
        scope: _scope,
        workspaceId: 'ws-1',
        seatId: 'seat-1',
        startsAt: _now,
        endsAt: _now.add(const Duration(hours: 2)),
        checkIn: false,
        schemaVersion: 350,
        createdAt: _now.subtract(const Duration(minutes: 5)),
      );
      await store.write(BookingIntentLedger.empty.upsert(intent).encode());
      final open = await _recovery(repo, store).unresolved();
      expect(open.single.status, BookingIntentStatus.unknown);
    });

    test('a check that finds nothing: resumable while young, unresolved '
        'beyond retention', () async {
      final repo = _repo();
      final store = InMemoryBookingIntentStore();
      final young = BookingIntent(
        requestId: 'r-young',
        scope: _scope,
        workspaceId: 'ws-1',
        seatId: 'seat-1',
        startsAt: _now,
        endsAt: _now.add(const Duration(hours: 2)),
        checkIn: false,
        schemaVersion: 350,
        createdAt: _now.subtract(const Duration(days: 1)),
        status: BookingIntentStatus.unknown,
      );
      final stale = BookingIntent(
        requestId: 'r-old',
        scope: _scope,
        workspaceId: 'ws-1',
        seatId: 'seat-1',
        startsAt: _now,
        endsAt: _now.add(const Duration(hours: 2)),
        checkIn: false,
        schemaVersion: 350,
        createdAt: _now.subtract(const Duration(days: 91)),
        status: BookingIntentStatus.unknown,
      );
      await store.write(
        BookingIntentLedger.empty.upsert(young).upsert(stale).encode(),
      );
      final recovery = _recovery(repo, store);
      expect(await recovery.check(young), isA<RecoveryNotCommitted>());
      expect(
        await recovery.check(stale),
        isA<RecoveryUnresolved>(),
        reason: 'absence beyond retention proves nothing',
      );
      expect(repo.outcomeCalls, 2);
      expect(repo.createCalls, 0, reason: 'a check never books');
      expect(
        (await recovery.unresolved()).length,
        2,
        reason: 'neither answer settles the intent by itself',
      );
      await recovery.discard(young);
      expect((await recovery.unresolved()).map((i) => i.requestId), ['r-old']);
    });

    test(
      'another account or server sees nothing and resumes nothing',
      () async {
        final repo = _repo()..failNextCreateTransport = true;
        final store = InMemoryBookingIntentStore();
        await expectLater(
          _recovery(repo, store).book(_request()),
          throwsA(isA<BookingOutcomeUnknown>()),
        );
        final mine = (await _recovery(repo, store).unresolved()).single;
        final theirs = _recovery(repo, store, scope: _other);
        expect(await theirs.unresolved(), isEmpty);
        expect(await theirs.check(mine), isA<RecoveryUnavailable>());
        expect(() => theirs.resume(mine), throwsStateError);
        expect(repo.reservations, hasLength(1));
      },
    );

    test(
      'a changed payload under the original id is refused by the server',
      () async {
        final repo = _repo();
        final store = InMemoryBookingIntentStore();
        await _recovery(repo, store).book(_request());
        final intent = BookingIntent(
          requestId: repo.lastRequestId!,
          scope: _scope,
          workspaceId: 'ws-1',
          seatId: 'seat-1',
          startsAt: _request().start,
          endsAt: _request().end.add(const Duration(hours: 1)),
          checkIn: false,
          schemaVersion: 350,
          createdAt: _now,
        );
        await expectLater(
          _recovery(repo, store).resume(intent),
          throwsA(predicate((e) => '$e'.contains('different booking'))),
        );
        expect(repo.reservations, hasLength(1));
      },
    );
  });

  group('persistence is part of the send', () {
    test('a device that cannot save the intent sends nothing', () async {
      final repo = _repo();
      final store = InMemoryBookingIntentStore()..failWrites = true;
      await expectLater(
        _recovery(repo, store).book(_request()),
        throwsA(isA<BookingIntentNotSaved>()),
      );
      expect(repo.createCalls, 0);
      expect(repo.reservations, isEmpty);
    });

    test(
      'a bookkeeping failure after a known commit keeps the commit',
      () async {
        final repo = _repo();
        final store = InMemoryBookingIntentStore();
        final recovery = _recovery(repo, store);
        // The save before the send succeeds; the settle after it fails.
        store.failWritesAfter = 1;
        final booked = await recovery.book(_request());
        expect(booked.reservationId, repo.reservations.single.id);
        expect(repo.reservations, hasLength(1));
        expect(store.writes, 2, reason: 'the settle was attempted');
      },
    );

    test(
      'a known refusal closes the intent and keeps the server\'s words',
      () async {
        final repo = _repo();
        final store = InMemoryBookingIntentStore();
        final recovery = _recovery(repo, store);
        // Two targets at once: the fake refuses before booking anything.
        final bad = BookingIntent(
          requestId: 'r-bad',
          scope: _scope,
          workspaceId: 'ws-1',
          seatId: 'seat-1',
          deskId: 'desk-1',
          startsAt: _now,
          endsAt: _now.add(const Duration(hours: 2)),
          checkIn: false,
          schemaVersion: 350,
          createdAt: _now,
          status: BookingIntentStatus.unknown,
        );
        await store.write(BookingIntentLedger.empty.upsert(bad).encode());
        await expectLater(
          recovery.resume(bad),
          throwsA(predicate((e) => '$e'.contains('exactly one of seat'))),
        );
        expect(
          await recovery.unresolved(),
          isEmpty,
          reason: 'a refusal is an answer',
        );
        expect(repo.reservations, isEmpty);
      },
    );
  });

  group('the ledger', () {
    test('round-trips, drops corrupt entries and stays bounded', () {
      final intent = BookingIntent(
        requestId: 'r-1',
        scope: _scope,
        workspaceId: 'ws-1',
        seatId: 'seat-1',
        startsAt: _now,
        endsAt: _now.add(const Duration(hours: 2)),
        checkIn: true,
        schemaVersion: 350,
        createdAt: _now,
      );
      final text = BookingIntentLedger.empty.upsert(intent).encode();
      final back = BookingIntentLedger.decode(text).intents.single;
      expect(back.requestId, 'r-1');
      expect(back.scope, _scope);
      expect(back.checkIn, isTrue);
      expect(back.startsAt, _now);
      expect(BookingIntentLedger.decode('not json').intents, isEmpty);
      expect(
        BookingIntentLedger.decode('[{"request_id": 1}]').intents,
        isEmpty,
      );
      expect(text, isNot(contains('token')));

      // 25 entries, 13 settled and 12 open: the cap drops settled ones
      // first, so every open question survives.
      var ledger = BookingIntentLedger.empty;
      for (var i = 0; i < BookingIntentLedger.cap + 5; i++) {
        ledger = ledger.upsert(
          BookingIntent(
            requestId: 'r-$i',
            scope: _scope,
            workspaceId: 'ws-1',
            seatId: 'seat-1',
            startsAt: _now,
            endsAt: _now.add(const Duration(hours: 2)),
            checkIn: false,
            schemaVersion: 350,
            createdAt: _now.add(Duration(seconds: i)),
            status: i.isEven
                ? BookingIntentStatus.committed
                : BookingIntentStatus.unknown,
          ),
        );
      }
      expect(ledger.intents.length, BookingIntentLedger.cap);
      expect(
        ledger.intents.where((i) => i.unresolved).length,
        12,
        reason: 'open questions outlive settled ones',
      );
      expect(
        ledger.byRequestId('r-0'),
        isNull,
        reason: 'the oldest settled left',
      );
    });

    test('RequestOutcome reads the server\'s answer exactly', () {
      expect(
        RequestOutcome.fromJson({'status': 'committed', 'reservation_id': 'r'})
            .status,
        RequestOutcomeStatus.committed,
      );
      expect(
        RequestOutcome.fromJson({'status': 'committed'}).status,
        RequestOutcomeStatus.unavailable,
        reason: 'committed without the reservation is not an answer',
      );
      expect(
        RequestOutcome.fromJson({'status': 'absent', 'retention_days': 30})
            .retentionDays,
        30,
      );
      expect(
        RequestOutcome.fromJson(null).status,
        RequestOutcomeStatus.unavailable,
      );
    });
  });
}
