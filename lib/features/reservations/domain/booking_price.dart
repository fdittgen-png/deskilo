// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3843 — what each booking of a period was or will be charged, as the
// server holds it (`booking_prices`, 0767): a room's charge with its amount
// in the business's currency; a pass or a carnet that paid for it; free
// (outside the counted hours, or a place outside the quota); covered by the
// member's subscription; or counting toward the month's extra half-days —
// with no amount, since the statement does not say which booking of a month
// was the extra one.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

/// The ways a booking is paid for, as `booking_prices` names them.
enum BookingPriceKind {
  charge,
  pass,
  carnet,
  free,
  subscription,
  overage;

  /// The kind [wire] names; null for a name this app does not know.
  static BookingPriceKind? fromWire(String? wire) =>
      values.where((k) => k.name == wire).firstOrNull;
}

/// One booking's price.
class BookingPrice {
  const BookingPrice({
    required this.reservationId,
    required this.kind,
    this.amountCents,
    this.currency,
  });

  /// A row of `booking_prices`; null when its kind is not one this app knows.
  static BookingPrice? fromRow(Object? row) {
    final r = JsonReader.of(row, context: 'booking_prices');
    final kind = BookingPriceKind.fromWire(r.stringOrNull('kind'));
    if (kind == null) return null;
    return BookingPrice(
      reservationId: r.string('reservation_id'),
      kind: kind,
      amountCents: r.intOrNull('amount_cents'),
      currency: r.stringOrNull('currency'),
    );
  }

  final String reservationId;
  final BookingPriceKind kind;

  /// A charge's amount in minor units, in [currency]; null for the others.
  final int? amountCents;
  final String? currency;

  /// A charge with its amount: what the period's total adds up.
  bool get isCharge =>
      kind == BookingPriceKind.charge &&
      amountCents != null &&
      currency != null;
}

/// The read of the prices of a period's bookings: one call per period.
abstract interface class BookingPriceReads {
  /// The prices of [workspaceId]'s bookings that overlap [from]–[to], as the
  /// person may read them (all, for whoever reads the finances; their own,
  /// for a member).
  Future<List<BookingPrice>> prices(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  });
}
