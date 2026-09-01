// SPDX-License-Identifier: 0BSD
import '../domain/booking_gate.dart';
import '../../../core/trace/act_trace.dart';
import '../../plan/domain/seat.dart';
import '../../workspace/domain/booking_granularity.dart';
import '../domain/reservation.dart';
import '../domain/seat_state_logic.dart';

/// #791 — the points in the map's tap flow that write down what the app
/// DECIDED, so a report of "check-in failed from the map" is answerable.
///
/// They live here rather than inline because each one needs more
/// explanation than code, and threading those paragraphs through
/// `reserve_seat_actions.dart` buried the dispatcher they annotate.
///
/// What they have in common: none of them marks an error. Every one
/// marks a branch that ends with the member seeing nothing happen.

/// The tap itself, with every input the branch below it turns on.
void traceSeatTap({
  required Seat seat,
  required SeatState state,
  required bool live,
  required BookingGranularity granularity,
  required String? member,
}) =>
    ActTrace.booking.step('seat-tap', {
      'seat': seat.id,
      'state': state.name,
      'live': live,
      'granularity': granularity.name,
      'member': member,
    });

/// The closed-day gate (#186), which returns before any sheet exists.
void traceClosedDay(Seat seat, DateTime windowStart) =>
    ActTrace.booking.refused('seat-tap', {
      'seat': seat.id,
      'reason': 'workspace-closed',
      'window': windowStart,
    });

/// The identity the whole seat-state calculation turns on.
///
/// A null member id is not cosmetic: [seatStateAt] compares it against
/// the holder, so while it is null the member's OWN booking reads as
/// somebody else's, and the map offers "Reserved by …" where it should
/// offer "Check in" — the exact shape of a report that arrived with an
/// empty trace. It gets its own line because it is invisible in the
/// outcome: the tap merely looks like it concerned another person.
void traceMemberIdentityMissing(Seat seat) =>
    ActTrace.booking.refused('member-identity-missing', {
      'seat': seat.id,
      'consequence': 'own-bookings-read-as-others',
    });

/// The seat is COLOURED as mine and the tap does nothing at all: the
/// state came from one resolver and the sheet's reservation from
/// another, and the two disagreed. Silent before, and indistinguishable
/// from a dead pixel by the person doing the tapping.
void traceCoveringReservationMissing({
  required Seat seat,
  required SeatState state,
  required bool live,
}) =>
    ActTrace.booking.refused('seat-tap', {
      'seat': seat.id,
      'reason': 'covering-reservation-not-resolved',
      'state': state.name,
      'live': live,
    });

/// Three independent gates decide whether checking someone else in is
/// even on the sheet, and the member sees only their sum. Naming the one
/// that closed turns "the check-in is missing" into a fact.
void traceCheckInNotOffered({
  required Seat seat,
  required Reservation other,
  required bool live,
  required bool mayCheckInOthers,
  required bool windowOpen,
}) =>
    ActTrace.booking.step('check-in-not-offered', {
      'seat': seat.id,
      'reservation': other.id,
      'holder': other.memberId,
      'live': live,
      'mayCheckInOthers': mayCheckInOthers,
      'windowOpen': windowOpen,
      'status': other.status.name,
    });

/// What the member's own sheet is about to OFFER, recorded before it
/// opens.
///
/// With the window shut the sheet shows a disabled tile reading
/// "Check-in opens at …" — a fine answer for the person holding the
/// phone and no answer at all for whoever reads the bug report. The
/// verdict AND the instants it came from go in, so a device clock
/// disagreeing with the workspace clock is visible rather than inferred.
void traceMySeatSheet({
  required Seat seat,
  required Reservation mine,
  required bool windowOpen,
  required DateTime now,
  required BookingGranularity granularity,
}) =>
    ActTrace.booking.step('my-seat-sheet', {
      'seat': seat.id,
      'reservation': mine.id,
      'status': mine.status.name,
      'windowOpen': windowOpen,
      'opensAt': mine.checkInOpensAt(granularity: granularity),
      'starts': mine.startsAt,
      'ends': mine.endsAt,
      'now': now,
      'granularity': granularity.name,
    });

/// What the member chose on their own sheet — including choosing
/// nothing, which is the outcome a shut check-in window produces.
void traceMySeatAction({
  required Reservation mine,
  required String? action,
  required bool windowOpen,
}) =>
    ActTrace.booking.step(action == null ? 'my-seat-dismissed' : 'my-seat-act', {
      'reservation': mine.id,
      'action': action,
      'windowOpen': windowOpen,
    });

/// The #772 shape, made visible: a tap on a free seat while the browsed
/// window contains NOW produces a plain reservation unless the walk-up
/// path or the "check in right away" switch asked for the check-in. To
/// the member that reads as "the map would not check me in", and it left
/// a trace only of the booking that DID happen.
void traceReserveWithoutCheckIn({
  required Seat seat,
  required DateTime start,
  required DateTime end,
}) =>
    ActTrace.booking.step('reserve-without-check-in', {
      'seat': seat.id,
      'reason': 'switch-off',
      'liveWindow': true,
      'from': start,
      'to': end,
    });

/// #814 — the gate refused before any sheet opened: WHICH rule, on
/// which seat, for a walk-up or a booking ahead. Beside the server-side
/// refusals this is what makes "the app would not let me" answerable.
void traceGateRefusal({
  required Seat seat,
  required BookingRefusal refusal,
  required bool walkUp,
}) =>
    ActTrace.booking.step('gate-refusal', {
      'seat': seat.id,
      'refusal': refusal.name,
      'walkUp': walkUp,
    });
