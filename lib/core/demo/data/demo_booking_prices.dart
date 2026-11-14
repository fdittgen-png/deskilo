// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3843 — what each booking of a Demo space's period is charged, by the rules
// of `booking_prices` (0767) over the space's own data:
//  * a whole room with a price per half-day: its charge, in the business's
//    currency (the half-days it spans, at the room's price);
//  * a booking inside a standing guest pass of its member: the pass;
//  * a booking a carnet's half-days cover (a use not released): the carnet;
//  * a booking of no seat (a room without a price, a level): free;
//  * any other: its member's month — the subscription, or the month's extra
//    half-days when the month has some (the statement's own figure).
// Who reads what is the server's rule: whoever reads the finances, every
// booking; a member, their own.
import '../../../features/money/domain/guest_pass.dart';
import '../../../features/money/domain/statement.dart';
import '../../../features/reservations/domain/booking_price.dart';
import '../../../features/reservations/domain/reservation.dart';
import 'credit_repository.dart';
import 'floor_plan_repository.dart';
import 'reservation_repository.dart';

/// The hours of a half-day, as the statement counts them.
const int _halfDayHours = 4;

/// The price read over one Demo space's stores.
class DemoBookingPriceReads implements BookingPriceReads {
  DemoBookingPriceReads({
    required this.reservations,
    required this.plan,
    required this.credits,
    required this.passes,
    required this.statement,
    required this.currency,
    required this.readsAll,
    required this.me,
  });

  final FakeReservationRepository reservations;
  final FakeFloorPlanRepository plan;
  final FakeCreditRepository credits;

  /// The passes sold in the space.
  final Future<List<GuestPassRecord>> Function() passes;

  /// A member's statement of a month (`YYYY-MM`).
  final Future<Statement> Function(String memberId, String month) statement;

  /// The business's currency, a charge's.
  final String currency;

  /// Whether the person reads the finances (every booking's price).
  final bool Function() readsAll;

  /// The person's member id: a member reads their own bookings' prices.
  final String? Function() me;

  @override
  Future<List<BookingPrice>> prices(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final all = readsAll();
    final mine = me();
    final shown =
        reservations.reservations
            .where(
              (r) =>
                  r.workspaceId == workspaceId &&
                  _counted.contains(r.status) &&
                  r.startsAt.isBefore(to) &&
                  r.endsAt.isAfter(from) &&
                  (all || r.memberId == mine),
            )
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final standing = [
      for (final p in await passes())
        if (!p.revoked) p,
    ];
    final carnet = {
      for (final u in credits.uses)
        if (u.releasedAt == null) u.reservationId,
    };
    final extra = <String, int>{};
    return [for (final r in shown) await _price(r, standing, carnet, extra)];
  }

  static const _counted = {
    ReservationStatus.reserved,
    ReservationStatus.checkedIn,
    ReservationStatus.completed,
  };

  Future<BookingPrice> _price(
    Reservation r,
    List<GuestPassRecord> standing,
    Set<String> carnet,
    Map<String, int> extra,
  ) async {
    BookingPrice of(BookingPriceKind kind) =>
        BookingPrice(reservationId: r.id, kind: kind);
    final room = plan.offices.where((o) => o.id == r.officeId).firstOrNull;
    if (room != null && room.priceCents > 0) {
      return BookingPrice(
        reservationId: r.id,
        kind: BookingPriceKind.charge,
        amountCents: room.priceCents * _halfDays(r),
        currency: currency,
      );
    }
    if (standing.any(
      (p) =>
          p.memberId == r.memberId &&
          !r.startsAt.isBefore(p.startsAt) &&
          !r.endsAt.isAfter(p.endsAt),
    )) {
      return of(BookingPriceKind.pass);
    }
    if (carnet.contains(r.id)) return of(BookingPriceKind.carnet);
    if (r.seatId == null) return of(BookingPriceKind.free);
    final month =
        '${r.startsAt.year}-${r.startsAt.month.toString().padLeft(2, '0')}';
    final key = '${r.memberId}/$month';
    final over = extra[key] ??= (await statement(
      r.memberId,
      month,
    )).extraHalfDays;
    return of(
      over > 0 ? BookingPriceKind.overage : BookingPriceKind.subscription,
    );
  }

  /// The half-days a booking spans, a started one counting whole.
  static int _halfDays(Reservation r) {
    final hours = r.endsAt.difference(r.startsAt).inMinutes / 60;
    return (hours / _halfDayHours).ceil().clamp(1, 1 << 16);
  }
}
