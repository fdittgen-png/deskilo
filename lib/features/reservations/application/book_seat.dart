// SPDX-License-Identifier: 0BSD
//
// #1234 — the first command of the application layer, and the shape the
// rest is meant to copy. ADR 0024 is the argument; this is the proof.
//
// What was here before: `reserve_seat_actions.dart`, 740 lines, holding
// the sheet, the gate, the trace, the three repository calls and the
// three success messages in one method. The decision "this booking is
// for somebody else, so it is a confirmation request rather than a
// reservation" sat inside a widget, where nothing could test it without
// pumping a screen.
//
// ## The rule this file exists to make true
//
// `presentation/` says what the member ASKED for. `application/` decides
// which write that is. `data/` performs it. A widget that reaches a
// repository directly is a widget holding orchestration, and that is
// what #1234 counted 125 of.
//
// ## What is deliberately NOT here
//
// No `BuildContext`, no `AppLocalizations`, no snack bar. The outcome is
// a value, and rendering it is presentation's job — which is exactly
// what lets this be tested with a fake repository and no widget tree.
//
// It also does not catch. A refusal from the server is information the
// member needs verbatim (#1030), and swallowing it here to return a
// tidier type would throw away the server's own words.
import '../domain/reservation_repository.dart';

/// What the member asked for, with nothing in it about how they asked.
///
/// A record rather than a class: it carries no behaviour, it is built at
/// one call site and read at one, and a class would add a constructor to
/// keep in step with the sheet for nothing.
typedef BookingRequest = ({
  String workspaceId,
  String seatId,
  DateTime start,
  DateTime end,

  /// Atomic walk-up: booked AND checked in, because somebody is already
  /// sitting there (#687).
  bool checkIn,

  /// Booking on behalf of another member (#106). Null books for me.
  String? forMemberId,

  /// A repeat (#seriesBooking). Null books once.
  SeriesPattern? pattern,
  DateTime? until,
});

/// What happened, in terms presentation can render without re-deriving
/// the decision that was made.
sealed class BookingOutcome {
  const BookingOutcome();
}

/// The seat is mine, from [start] to [end]. [checkedIn] says whether the
/// server also checked me in, because telling somebody standing at a
/// desk that they merely reserved it is the confirmation lying (#687).
final class Booked extends BookingOutcome {
  const Booked({
    required this.reservationId,
    required this.start,
    required this.end,
    required this.checkedIn,
  });

  final String reservationId;
  final DateTime start;
  final DateTime end;
  final bool checkedIn;
}

/// Booked FOR somebody: they have agreed to nothing yet, so this is a
/// confirmation request and never a check-in (#106).
final class SentForConfirmation extends BookingOutcome {
  const SentForConfirmation({
    required this.reservationId,
    required this.subjectMemberId,
  });

  final String reservationId;
  final String subjectMemberId;
}

/// A repeat: some of its dates may have been refused, and the caller
/// shows which.
final class SeriesBooked extends BookingOutcome {
  const SeriesBooked(this.result);

  final SeriesResult result;
}

/// Makes the booking the request describes.
///
/// The three branches are the whole reason this function exists: which
/// write a booking IS depends on who it is for and whether it repeats,
/// and that decision belongs somewhere a test can reach without a
/// widget.
///
/// Throws whatever the repository throws. See the note above.
Future<BookingOutcome> bookSeat(
  ReservationRepository reservations,
  BookingRequest request, {
  required String? myMemberId,
}) async {
  final forSomeoneElse = request.forMemberId != null &&
      request.forMemberId != myMemberId;

  if (forSomeoneElse) {
    // Never a check-in, whatever the request said: the subject is not
    // standing at the desk, and may yet decline.
    final id = await reservations.createFor(
      workspaceId: request.workspaceId,
      subjectMemberId: request.forMemberId!,
      seatId: request.seatId,
      startsAt: request.start,
      endsAt: request.end,
    );
    return SentForConfirmation(
      reservationId: id,
      subjectMemberId: request.forMemberId!,
    );
  }

  if (request.pattern != null) {
    return SeriesBooked(await reservations.createSeries(
      workspaceId: request.workspaceId,
      seatId: request.seatId,
      firstStart: request.start,
      firstEnd: request.end,
      pattern: request.pattern!,
      until: request.until!,
    ));
  }

  final id = await reservations.create(
    workspaceId: request.workspaceId,
    seatId: request.seatId,
    startsAt: request.start,
    endsAt: request.end,
    checkIn: request.checkIn,
  );
  return Booked(
    reservationId: id,
    start: request.start,
    end: request.end,
    checkedIn: request.checkIn,
  );
}
