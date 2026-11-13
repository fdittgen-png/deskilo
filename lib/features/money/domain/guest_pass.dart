// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3308 — a pass sold at the desk to a guest who is not a member: the
// space's passes, the sale's draft and its rules, and what the sale made.
// The server prices the pass and books, charges and invoices it
// (sell_guest_pass, 0685); these rules only keep a draft from being sent
// that the server would refuse for a reason the form can name.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// What a pass is counted in.
enum GuestPassUnit {
  day('day'),
  hour('hour');

  const GuestPassUnit(this.wire);
  final String wire;

  static GuestPassUnit? fromWire(String? wire) =>
      values.where((u) => u.wire == wire).firstOrNull;
}

/// The longest pass the server sells, in days (one booking per day).
const guestPassMaxDays = 31;

/// One pass of the space's list.
class GuestPassOffer implements SystemStamped {
  const GuestPassOffer({
    required this.id,
    required this.name,
    required this.unit,
    required this.priceCents,
    this.vatRateId,
    this.active = true,
    this.system = SystemColumns.none,
  });

  factory GuestPassOffer.fromJson(Map<String, Object?> json) {
    final r = JsonReader(json, context: 'guest_pass_offers');
    return GuestPassOffer(
      system: SystemColumns.fromRow(json),
      id: r.string('id'),
      name: r.string('name'),
      unit: GuestPassUnit.fromWire(r.stringOrNull('unit')) ?? GuestPassUnit.day,
      priceCents: r.integer('price_cents'),
      vatRateId: r.stringOrNull('vat_rate_id'),
      active: r.boolOr('active', fallback: true),
    );
  }

  /// #992 — the server's stamp on this row.
  @override
  final SystemColumns system;

  final String id;
  final String name;
  final GuestPassUnit unit;

  /// The price of one unit, in minor units of the space's currency.
  final int priceCents;
  final String? vatRateId;
  final bool active;
}

/// What the person at the desk is about to sell.
class GuestPassDraft {
  const GuestPassDraft({
    required this.offer,
    required this.seatId,
    required this.day,
    required this.startMinutes,
    required this.endMinutes,
    this.days = 1,
    this.paid = false,
    this.method = '',
  });

  final GuestPassOffer? offer;
  final String? seatId;

  /// The first day, local to the space (its time of day is ignored).
  final DateTime day;

  /// The window of each day, in minutes after local midnight.
  final int startMinutes;
  final int endMinutes;

  /// How many consecutive days a day pass lasts; an hourly pass is one.
  final int days;

  /// Whether the money was taken at the desk (recorded as a payment).
  final bool paid;
  final String method;

  DateTime get startsAt =>
      DateTime(day.year, day.month, day.day, 0, startMinutes);
  DateTime get endsAt => DateTime(day.year, day.month, day.day, 0, endMinutes);
}

/// Why a draft cannot be sold.
enum GuestPassProblem { noOffer, noSeat, endBeforeStart, daysOutOfRange, hourlyOneDay }

/// The draft's problems, in the order the form shows them; empty = sellable.
List<GuestPassProblem> guestPassProblems(GuestPassDraft d) => [
  if (d.offer == null) GuestPassProblem.noOffer,
  if (d.seatId == null) GuestPassProblem.noSeat,
  if (d.endMinutes <= d.startMinutes) GuestPassProblem.endBeforeStart,
  if (d.days < 1 || d.days > guestPassMaxDays) GuestPassProblem.daysOutOfRange,
  if (d.offer?.unit == GuestPassUnit.hour && d.days != 1)
    GuestPassProblem.hourlyOneDay,
];

/// The units a draft is charged for — as the server counts them: the
/// window's started hours for an hourly pass, the number of days for a
/// day pass. Shown before the sale; the server's own count is the price.
int guestPassUnits(GuestPassDraft d) => switch (d.offer?.unit) {
  GuestPassUnit.hour => ((d.endMinutes - d.startMinutes) / 60).ceil(),
  _ => d.days,
};

/// The amount a draft will cost, in minor units.
int guestPassAmountCents(GuestPassDraft d) =>
    guestPassUnits(d) * (d.offer?.priceCents ?? 0);

/// What a sale made.
class GuestPassSale {
  const GuestPassSale({
    required this.passId,
    required this.memberId,
    required this.reservationIds,
    required this.units,
    required this.amountCents,
    this.invoiceId,
    this.paymentEventId,
    this.replayed = false,
  });

  factory GuestPassSale.fromJson(Map<String, Object?> json) {
    final r = JsonReader(json, context: 'sell_guest_pass');
    return GuestPassSale(
      passId: r.string('pass_id'),
      memberId: r.string('member_id'),
      reservationIds: r.strings('reservation_ids'),
      units: r.integer('units'),
      amountCents: r.integer('amount_cents'),
      invoiceId: r.stringOrNull('invoice_id'),
      paymentEventId: r.stringOrNull('payment_event_id'),
      replayed: r.boolOr('replayed', fallback: false),
    );
  }

  final String passId;

  /// The guest's customer record (not a membership).
  final String memberId;
  final List<String> reservationIds;
  final int units;
  final int amountCents;
  final String? invoiceId;
  final String? paymentEventId;

  /// A retry of a sale already made: nothing was done twice.
  final bool replayed;
}

/// A place a pass can book, named the way the desk reads it.
typedef GuestPassPlace = ({String seatId, String label});

/// #3614 — a pass sold: who holds it, which pass, its window and price.
class GuestPassRecord {
  const GuestPassRecord({
    required this.id,
    required this.memberId,
    required this.offerId,
    required this.unit,
    required this.units,
    required this.amountCents,
    required this.startsAt,
    required this.endsAt,
  });

  factory GuestPassRecord.fromJson(Map<String, Object?> json) {
    final r = JsonReader(json, context: 'guest_passes');
    return GuestPassRecord(
      id: r.string('id'),
      memberId: r.string('member_id'),
      offerId: r.string('offer_id'),
      unit: GuestPassUnit.fromWire(r.string('unit')) ?? GuestPassUnit.day,
      units: r.integer('units'),
      amountCents: r.integer('amount_cents'),
      startsAt: DateTime.parse(r.string('starts_at')),
      endsAt: DateTime.parse(r.string('ends_at')),
    );
  }

  final String id;

  /// The guest's customer record.
  final String memberId;
  final String offerId;
  final GuestPassUnit unit;
  final int units;
  final int amountCents;

  /// The first day's start and the last day's end, as instants.
  final DateTime startsAt;
  final DateTime endsAt;

  /// The units already started at [now]: the days begun of a day pass,
  /// counted on the business's calendar ([dayOf]); an hourly pass is one
  /// window, all of it once it began.
  int usedAt(DateTime now, DateTime Function(DateTime instant) dayOf) {
    if (now.isBefore(startsAt)) return 0;
    if (unit == GuestPassUnit.hour) return units;
    // Whole days between two calendar days, a summer-time day included.
    final days = dayOf(now).difference(dayOf(startsAt)).inHours / 24;
    return (days.round() + 1).clamp(0, units);
  }
}

/// The space's passes and their sale.
abstract interface class GuestPassRepository {
  Future<List<GuestPassOffer>> offers(String workspaceId);

  /// #3614 — the passes sold in the space, the latest first. Read by who
  /// holds viewFinances or issueInvoices, or the owner (0685's policy).
  Future<List<GuestPassRecord>> passesSold(String workspaceId);

  /// Every seat of the space, level by level: the places a pass can book.
  /// The server checks the place is free and the window open.
  Future<List<GuestPassPlace>> places(String workspaceId);

  /// Creates ([id] null) or changes a pass; returns its id.
  Future<String> saveOffer(
    String workspaceId, {
    String? id,
    required String name,
    required GuestPassUnit unit,
    required int priceCents,
    String? vatRateId,
    bool active = true,
  });

  /// Sells [draft] to the guest named by [guest] (the identity form's
  /// wire keys). The same [requestId] never sells twice.
  Future<GuestPassSale> sell(
    String workspaceId, {
    required GuestPassDraft draft,
    required Map<String, Object?> guest,
    required String requestId,
  });
}

/// Why a pass of the list cannot be saved.
enum GuestPassOfferProblem { name, price }

/// The problems of a pass being edited ([priceCents] null = unreadable).
Set<GuestPassOfferProblem> guestPassOfferProblems(String name, int? priceCents) => {
  if (name.trim().isEmpty) GuestPassOfferProblem.name,
  if (priceCents == null || priceCents < 0) GuestPassOfferProblem.price,
};
