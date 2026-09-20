// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1234 — the third command of the application layer, and the one ADR
// 0024 named next: "`reserve_seat_actions.dart` still calls repositories
// for check-in, cancel and seat blocking."
//
// This is cancel and reschedule. `reservation_detail_sheet.dart` held
// both, and held them as strings: the cancel choice travelled out of a
// bottom sheet as `'single'` or `'following'` and was compared with `==`
// at the call site. A decision with two branches and no type.
//
// ## What is decided here
//
// Cancelling:
//   - a lone booking            -> cancel it
//   - one occurrence of a repeat -> cancel that occurrence
//   - this and the following     -> cancel the tail from this date
//
// Rescheduling:
//   - a new window               -> updateTimes
//   - a new window AND a pattern -> convertToSeries (#1394), which is
//                                   ONE transaction on the server
//   - an end change on a running booking -> updateTimes, start untouched
//
// ## Why the conversion is not two writes any more
//
// It used to be `cancel(r.id)` then `createSeries(...)`. Each is
// transactional alone; the composition was not — and the failure is the
// ordinary path rather than a race. `create_series` reports a date it
// cannot book as SKIPPED rather than raising, so when nothing can be
// booked it returns normally with an empty `booked`, the client's
// try/catch never fires, and the member is left with the original
// cancelled and nothing in its place.
//
// Demonstrated on the dev project before the fix, rolled back:
//
//     after_cancel=cancelled | series_raised=NO booked=0 skipped=3
//     | member_live_rows_now=0
//
// `convert_to_series` (0224) does both in one transaction and refuses
// when the repeat books nothing, so the cancel rolls back with it.
//
// ## What is deliberately NOT here
//
// No `BuildContext`, no `AppLocalizations`, no snack bar, no `ref` — the
// outcome is a value and rendering it is presentation's job. And it does
// not catch: a refusal carries the server's own words, which is what
// `bookingErrorText` needs to map (#1030).
import '../domain/reservation.dart';
import '../domain/reservation_repository.dart';

/// Which of a repeat's occurrences a cancellation touches.
///
/// A type rather than the `'single'` / `'following'` strings the sheet
/// used to pop: there are exactly two answers and the compiler can say
/// so.
enum CancelScope {
  /// This booking alone — the whole thing when it is not a repeat.
  thisOne,

  /// This occurrence and every later one in the same series.
  thisAndFollowing,
}

/// What a cancellation did.
sealed class CancelOutcome {
  const CancelOutcome();
}

/// One booking is cancelled.
final class CancelledOne extends CancelOutcome {
  const CancelledOne(this.reservationId);

  final String reservationId;
}

/// [count] occurrences of the series were cancelled, from this one on.
final class CancelledFollowing extends CancelOutcome {
  const CancelledFollowing({required this.seriesId, required this.count});

  final String seriesId;
  final int count;
}

/// What a reschedule did.
sealed class RescheduleOutcome {
  const RescheduleOutcome();
}

/// The booking kept its identity and moved.
final class Moved extends RescheduleOutcome {
  const Moved({required this.reservationId, required this.start, required this.end});

  final String reservationId;
  final DateTime start;
  final DateTime end;
}

/// The booking became a repeat. [result] carries the dates that were
/// booked AND the ones skipped — a partial repeat is a real outcome the
/// caller must show, which is why this is not reduced to a bool.
final class BecameSeries extends RescheduleOutcome {
  const BecameSeries(this.result);

  final SeriesResult result;
}

/// Cancels [reservation], or the tail of its series.
///
/// `thisAndFollowing` is only meaningful for a booking that belongs to a
/// series; asking for it on a lone booking cancels that booking, because
/// "this and the following" of a set of one is that one.
///
/// Throws whatever the repository throws.
Future<CancelOutcome> cancelReservation(
  ReservationRepository reservations,
  Reservation reservation, {
  required CancelScope scope,
}) async {
  final seriesId = reservation.seriesId;
  if (scope == CancelScope.thisAndFollowing && seriesId != null) {
    final count = await reservations.cancelSeries(
      seriesId,
      from: reservation.startsAt,
    );
    return CancelledFollowing(seriesId: seriesId, count: count);
  }
  await reservations.cancel(reservation.id);
  return CancelledOne(reservation.id);
}

/// Moves [reservation] to a new window, or turns it into a repeat.
///
/// [pattern] and [until] travel together: a pattern without an end is
/// not a repeat anybody asked for, and `convert_to_series` needs both.
/// When [pattern] is null the booking simply moves.
///
/// Throws whatever the repository throws — including the refusal when a
/// conversion can book no date at all, which leaves the original
/// untouched (#1394).
Future<RescheduleOutcome> rescheduleReservation(
  ReservationRepository reservations,
  Reservation reservation, {
  required DateTime start,
  required DateTime end,
  SeriesPattern? pattern,
  DateTime? until,
}) async {
  if (pattern != null) {
    if (until == null) {
      throw ArgumentError('a repeat needs an end date');
    }
    // #1562 — the chosen window travels into the conversion. It used to
    // stop here, so editing the times and adding a repeat in one gesture
    // built the repeat from the STORED window: the member asked for
    // 14:00–16:00 and received 09:00–10:00, and the per-date conflict
    // checks answered for the wrong hours too.
    return BecameSeries(await reservations.convertToSeries(
      reservation.id,
      start: start,
      end: end,
      pattern: pattern,
      until: until,
    ));
  }
  await reservations.updateTimes(
    reservation.id,
    startsAt: start,
    endsAt: end,
  );
  return Moved(reservationId: reservation.id, start: start, end: end);
}

/// Changes only the END of a booking, keeping its start.
///
/// A running booking may not move its start (`update_reservation` v2
/// refuses it), and the sheet's two end-change affordances both mean
/// "I am leaving at a different time", never "I arrived at a different
/// time". Naming that here keeps the start out of the caller's hands.
Future<Moved> changeReservationEnd(
  ReservationRepository reservations,
  Reservation reservation, {
  required DateTime end,
}) async {
  await reservations.updateTimes(
    reservation.id,
    startsAt: reservation.startsAt,
    endsAt: end,
  );
  return Moved(
    reservationId: reservation.id,
    start: reservation.startsAt,
    end: end,
  );
}
