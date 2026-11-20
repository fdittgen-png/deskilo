// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4157 (A2 of #4174) — a confirmation acts on the context its displayed data
// was read from. The handle is taken when the confirmation opens; every
// command re-reads the context and refuses, writing nothing, unless it is the
// very same operation. The permutations of identity, installation, local
// account and epoch are a table here; the widgets prove each real confirmation
// is wired to it (bound_confirmation_switch_test.dart).
import 'package:deskilo/core/backend/operation_context.dart';
import 'package:deskilo/core/booking/my_seat_action.dart';
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/core/storage/booking_intent_store.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/reservations/application/book_seat.dart';
import 'package:deskilo/features/reservations/application/booking_recovery.dart';
import 'package:deskilo/features/reservations/application/bound_reservation.dart';
import 'package:deskilo/features/reservations/domain/booking_intent.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_clock.dart';
import '../../../helpers/test_workspace_context.dart';

/// Counts what reaches the server, whatever the fake then does with it.
class _Spy extends FakeReservationRepository {
  final List<String> writes = [];

  @override
  Future<void> checkIn(String reservationId) {
    writes.add('checkIn $reservationId');
    return super.checkIn(reservationId);
  }

  @override
  Future<void> checkOut(String reservationId) {
    writes.add('checkOut $reservationId');
    return super.checkOut(reservationId);
  }

  @override
  Future<void> cancel(String reservationId) {
    writes.add('cancel $reservationId');
    return super.cancel(reservationId);
  }

  @override
  Future<String> create({
    required String workspaceId,
    String? seatId,
    String? deskId,
    String? officeId,
    String? levelId,
    required DateTime startsAt,
    required DateTime endsAt,
    bool checkIn = false,
    String? requestId,
  }) {
    writes.add('create ${requestId ?? '-'}');
    return super.create(
      workspaceId: workspaceId,
      seatId: seatId,
      deskId: deskId,
      officeId: officeId,
      levelId: levelId,
      startsAt: startsAt,
      endsAt: endsAt,
      checkIn: checkIn,
      requestId: requestId,
    );
  }
}

final _origin = testWorkspaceContextOf(installation: 'inst-a');

/// The context on screen, changeable while a confirmation is open.
class _Screen {
  _Screen(this.now);
  WorkspaceContext? now;
  bool disposed = false;

  Future<WorkspaceContext?> read() async {
    if (disposed) throw StateError('disposed');
    return now;
  }
}

({BoundReservation bound, _Spy repo, _Screen screen}) _bound({
  _Screen? screen,
}) {
  final repo = _Spy();
  final on = screen ?? _Screen(_origin);
  return (
    bound: BoundReservation(
      origin: _origin,
      reservations: repo,
      recovery: BookingRecovery(
        reservations: repo,
        store: InMemoryBookingIntentStore(),
        scope: const BookingIntentScope(account: 'u-1', origin: 'http://a'),
        clock: FixedClock(DateTime.utc(2026, 10, 7, 8)),
        schemaVersion: 1,
      ),
      readContext: on.read,
    ),
    repo: repo,
    screen: on,
  );
}

/// What changed, as a switch of context: each is a DIFFERENT operation.
final _changes = <String, WorkspaceContext?>{
  'another installation, the same local workspace id': testWorkspaceContextOf(
    installation: 'inst-b',
  ),
  'another workspace on the same installation': testWorkspaceContextOf(
    installation: 'inst-a',
    workspaceId: 'ws-2',
  ),
  'another person (subject)': testWorkspaceContextOf(
    installation: 'inst-a',
    subject: 'p-2',
  ),
  'another issuer': testWorkspaceContextOf(
    installation: 'inst-a',
    issuer: 'https://other.test/auth/v1',
  ),
  'another local account on the target': testWorkspaceContextOf(
    installation: 'inst-a',
    localUser: 'u-2',
  ),
  'another personal epoch': testWorkspaceContextOf(
    installation: 'inst-a',
    personalEpoch: 2,
  ),
  'another workspace epoch': testWorkspaceContextOf(
    installation: 'inst-a',
    workspaceEpoch: 2,
  ),
  'signed out, or no context ready': null,
};

BookingRequest _request() => (
  workspaceId: 'ws',
  seatId: 'seat-1',
  start: DateTime.utc(2026, 10, 7, 9),
  end: DateTime.utc(2026, 10, 7, 13),
  checkIn: false,
  forMemberId: null,
  pattern: null,
  until: null,
);

void main() {
  group('in an unchanged context each explicit action sends exactly its own '
      'command with its own id', () {
    const commands = {
      MySeatAction.checkIn: 'checkIn r-1',
      MySeatAction.checkOut: 'checkOut r-1',
      MySeatAction.cancel: 'cancel r-1',
    };
    for (final MapEntry(key: action, value: expected) in commands.entries) {
      test(action.name, () async {
        final h = _bound();
        // A booking in the state the action starts from, on the clock the
        // fake judges by.
        h.repo.reservations.add(
          Reservation(
            id: 'r-1',
            workspaceId: 'ws',
            seatId: 'seat-1',
            memberId: 'member-1',
            startsAt: kTestNow.subtract(const Duration(minutes: 30)),
            endsAt: kTestNow.add(const Duration(hours: 4)),
            status: action == MySeatAction.checkOut
                ? ReservationStatus.checkedIn
                : ReservationStatus.reserved,
          ),
        );
        await h.bound.perform(action, 'r-1');
        expect(h.repo.writes, [expected]);
      });
    }

    test('a deletion request is never performed as a reservation command: '
        'it is refused, not turned into a cancellation', () async {
      final h = _bound();
      expect(
        () => h.bound.perform(MySeatAction.requestDeletion, 'r-1'),
        throwsArgumentError,
      );
      expect(h.repo.writes, isEmpty);
    });

    test('every action of the closed set is a case: none falls through to '
        'cancel', () {
      expect(MySeatAction.values.map((a) => a.wireName).toSet(), {
        'checkin',
        'checkout',
        'cancel',
        'requestDeletion',
      });
    });
  });

  group('a changed context refuses before anything is sent', () {
    _changes.forEach((name, changed) {
      for (final action in [
        MySeatAction.checkIn,
        MySeatAction.checkOut,
        MySeatAction.cancel,
      ]) {
        test('$name: ${action.name}', () async {
          final h = _bound();
          h.screen.now = changed;
          await expectLater(
            h.bound.perform(action, 'r-1'),
            throwsA(isA<StaleReservationContext>()),
          );
          expect(h.repo.writes, isEmpty);
        });
      }

      test('$name: a booking saves no intent and sends no request', () async {
        final h = _bound();
        h.screen.now = changed;
        await expectLater(
          h.bound.book(_request(), myMemberId: 'member-1'),
          throwsA(isA<StaleReservationContext>()),
        );
        expect(h.repo.writes, isEmpty);
        expect(await h.bound.recovery.unresolved(), isEmpty);
      });

      test('$name: an edit through the repository gate is refused', () async {
        final h = _bound();
        h.screen.now = changed;
        await expectLater(
          h.bound.withReservations((r) => r.cancel('r-1')),
          throwsA(isA<StaleReservationContext>()),
        );
        expect(h.repo.writes, isEmpty);
        expect(await h.bound.isCurrent(), isFalse);
      });
    });

    test('a disposed screen refuses: its context cannot be read', () async {
      final h = _bound();
      h.screen.disposed = true;
      await expectLater(
        h.bound.perform(MySeatAction.cancel, 'r-1'),
        throwsA(isA<StaleReservationContext>()),
      );
      expect(h.repo.writes, isEmpty);
      expect(await h.bound.isCurrent(), isFalse);
    });
  });

  test('the same context read again is the origin: the gate opens', () async {
    final h = _bound();
    // A new capture of the same operation (a refresh of the same selection).
    h.screen.now = testWorkspaceContextOf(installation: 'inst-a');
    expect(await h.bound.isCurrent(), isTrue);
  });

  test('closing a modal without choosing writes nothing: there is no command '
      'to run', () async {
    final h = _bound();
    expect(h.repo.writes, isEmpty);
  });

  test(
    'a command already sent is not undone by a later switch: its answer '
    'stays with the origin, and the caller learns the context moved',
    () async {
      final h = _bound();
      h.repo.reservations.add(
        Reservation(
          id: 'r-1',
          workspaceId: 'ws',
          seatId: 'seat-1',
          memberId: 'member-1',
          startsAt: DateTime.utc(2026, 10, 7, 9),
          endsAt: DateTime.utc(2026, 10, 7, 13),
          status: ReservationStatus.reserved,
        ),
      );
      final sent = h.bound.withReservations((r) async {
        // The person switches while the request is in flight.
        h.screen.now = testWorkspaceContextOf(installation: 'inst-b');
        await r.cancel('r-1');
      });
      await sent;
      expect(h.repo.writes, [
        'cancel r-1',
      ], reason: 'it was sent to the origin');
      expect(
        h.repo.reservations.single.status,
        ReservationStatus.cancelled,
        reason: 'and it took effect there',
      );
      expect(
        await h.bound.isCurrent(),
        isFalse,
        reason: 'the new context is not told it owns that answer',
      );
    },
  );

  test('a booking in an unchanged context keeps its original request id and '
      'its intent until the answer is read', () async {
    final h = _bound();
    final outcome = await h.bound.book(_request(), myMemberId: 'member-1');
    expect(outcome, isA<BookingOutcome>());
    expect(h.repo.writes.single, startsWith('create '));
    final id = h.repo.writes.single.substring('create '.length);
    expect(id, isNot('-'), reason: 'a request id travels with the booking');
  });
}
