// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1234 — the second command of the application layer. ADR 0024 named
// this one: "`reserve_seat_actions.dart` still calls repositories for
// check-in, cancel and seat blocking. Those are the next commands, and
// the count says so."
//
// ## What was here before
//
// `space_act_sheet.dart`, `_confirm`, lines 172-287: a four-way decision
// about what a member standing at a seat actually asked for, wrapped in
// a bottom sheet. To find out whether a member already checked in gets
// refused, `already_checked_in_test.dart` boots `DeskiloApp`, taps the
// scan button, types a space code, submits, and inspects widget keys —
// 219 lines of widget driving for a decision that is five comparisons.
//
// ## The decision, which is the whole reason this file exists
//
// Check in:
//   - my reservation here that the check-in rules accept  -> check THAT in
//   - my LIVE check-in here covering this window          -> refuse, say so
//   - otherwise                                            -> walk up and create
//
// Check out:
//   - my live check-in here -> check THAT out
//   - none                  -> refuse, say so
//
// The middle check-in branch is #1135. `checkInWindowOpen` opens with
// `status != reserved -> false`, so a reservation the member is already
// checked into is invisible to the target predicate; it returns null,
// and the old code read that null as "nothing of mine here, walk up".
// The server refused, correctly, and the member was told something they
// could not act on — five identical creates in two and a half seconds,
// from the field trace of 2026-09-11.
//
// ## What is deliberately NOT here
//
// No `BuildContext`, no `AppLocalizations`, no `AppSnack`, no `ref`. The
// refusals come back as outcome VALUES and presentation renders them —
// which is what lets every case below be a plain test with a fake
// repository and no widget tree.
//
// It does not catch, either. `bookingErrorText` maps a server refusal to
// the member's language and the sheet keeps doing that; swallowing it
// here would throw away the server's own words (#1030).
import '../../workspace/domain/booking_granularity.dart';
import '../domain/reservation.dart';
import '../domain/reservation_repository.dart';
import '../domain/space_act.dart';

/// What happened, in terms presentation can render without re-deriving
/// the decision that was made.
sealed class SpaceActOutcome {
  const SpaceActOutcome();
}

/// Checked into a reservation that already existed. Never a create.
final class CheckedIntoExisting extends SpaceActOutcome {
  const CheckedIntoExisting(this.reservationId);

  final String reservationId;
}

/// The seat was free, so the walk-up created and checked in atomically
/// (#687): somebody is sitting there already.
final class WalkedUp extends SpaceActOutcome {
  const WalkedUp(this.reservationId);

  final String reservationId;
}

/// A plain reservation, with [checkedIn] saying whether the server was
/// also asked to check in.
final class Reserved extends SpaceActOutcome {
  const Reserved({required this.reservationId, required this.checkedIn});

  final String reservationId;
  final bool checkedIn;
}

/// Left the seat.
final class CheckedOut extends SpaceActOutcome {
  const CheckedOut(this.reservationId);

  final String reservationId;
}

/// #1135 — already checked in HERE, covering this window, so checking in
/// again is impossible. A value rather than an exception: nothing went
/// wrong, the member simply asked for something they already have, and
/// the answer is "choose Check out to leave".
///
/// The request must never reach the repository. `createCalls` in the
/// fake counts entries precisely so a test can tell "the app never
/// asked" from "the app asked and the server said no".
final class AlreadyCheckedInHere extends SpaceActOutcome {
  const AlreadyCheckedInHere(this.reservationId);

  final String reservationId;
}

/// Asked to check out with nothing live here — the plan may have just
/// updated under the member.
final class NoActiveCheckIn extends SpaceActOutcome {
  const NoActiveCheckIn();
}

/// MY reservation of [seatId] the check-in rules accept (#600).
///
/// Gates on `checkInWindowOpen`, whose first clause is
/// `status != reserved -> false` — so this deliberately cannot see a
/// reservation already checked into. [myLiveCheckInHere] is the one that
/// can, and #1135 is what happens when only this one is consulted.
Reservation? myCheckInTarget(
  List<Reservation> reservations,
  DateTime now,
  String? myMemberId, {
  required String seatId,
  required BookingGranularity granularity,
}) =>
    reservations
        .where((r) =>
            r.memberId == myMemberId &&
            r.seatId == seatId &&
            r.checkInWindowOpen(now, granularity: granularity))
        .firstOrNull;

/// MY live check-in ON THIS SEAT (#1083).
///
/// The seat predicate is the whole point: with
/// `simultaneous_reservations > 1` a member can hold two seats at once,
/// and scanning one of them must release THAT one. Without it the branch
/// took `firstOrNull` of an unordered list and checked the member out of
/// whichever seat came first.
///
/// Ordered by check-in time so that even a seat holding two live rows —
/// which the server should never allow — resolves the same way twice
/// rather than by list order.
Reservation? myActiveCheckIn(
  List<Reservation> reservations,
  DateTime now,
  String? myMemberId, {
  required String seatId,
}) {
  final mine = reservations
      .where((r) =>
          r.memberId == myMemberId &&
          r.seatId == seatId &&
          r.status == ReservationStatus.checkedIn &&
          r.endsAt.isAfter(now))
      .toList()
    ..sort((a, b) =>
        (a.checkedInAt ?? a.startsAt).compareTo(b.checkedInAt ?? b.startsAt));
  return mine.isEmpty ? null : mine.last;
}

/// Performs the act the member chose.
///
/// Throws whatever the repository throws. See the note at the top.
Future<SpaceActOutcome> actOnSpace(
  ReservationRepository reservations,
  SpaceActRequest request,
) async {
  final choice = request.choice;

  switch (choice.action) {
    case SpaceAction.checkIn:
      final mine = myCheckInTarget(
        request.dayReservations,
        request.now,
        request.myMemberId,
        seatId: request.seatId,
        granularity: request.granularity,
      );
      if (mine != null) {
        await reservations.checkIn(mine.id);
        return CheckedIntoExisting(mine.id);
      }

      // #1135 — invisible to the target predicate, and the reason this
      // branch exists. Only an OVERLAPPING live check-in makes the
      // request impossible: a member sitting here this morning may
      // reserve this seat for the afternoon, and `enforce_one_place`
      // counts overlaps and nothing else, so this must not be stricter
      // than the server.
      final live = myActiveCheckIn(
        request.dayReservations,
        request.now,
        request.myMemberId,
        seatId: request.seatId,
      );
      if (live != null && live.coversRange(choice.start, choice.end)) {
        return AlreadyCheckedInHere(live.id);
      }

      final id = await reservations.create(
        workspaceId: request.workspaceId,
        seatId: request.seatId,
        startsAt: choice.start,
        endsAt: choice.end,
        checkIn: true,
      );
      return WalkedUp(id);

    case SpaceAction.reserve:
      final id = await reservations.create(
        workspaceId: request.workspaceId,
        seatId: request.seatId,
        startsAt: choice.start,
        endsAt: choice.end,
        checkIn: choice.checkInNow,
      );
      return Reserved(reservationId: id, checkedIn: choice.checkInNow);

    case SpaceAction.checkOut:
      final active = myActiveCheckIn(
        request.dayReservations,
        request.now,
        request.myMemberId,
        seatId: request.seatId,
      );
      if (active == null) return const NoActiveCheckIn();
      await reservations.checkOut(active.id);
      return CheckedOut(active.id);
  }
}
