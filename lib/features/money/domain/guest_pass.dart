// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3308 — a pass sold at the desk to a guest who is not a member: the
// space's passes, the sale's draft and its rules, and what the sale made.
// The server prices the pass and books, charges and invoices it
// (sell_guest_pass, 0672); these rules only keep a draft from being sent
// that the server would refuse for a reason the form can name.

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
class GuestPassOffer {
  const GuestPassOffer({
    required this.id,
    required this.name,
    required this.unit,
    required this.priceCents,
    this.vatRateId,
    this.active = true,
  });

  factory GuestPassOffer.fromJson(Map<String, dynamic> json) => GuestPassOffer(
    id: json['id'] as String,
    name: json['name'] as String,
    unit: GuestPassUnit.fromWire(json['unit'] as String?) ?? GuestPassUnit.day,
    priceCents: (json['price_cents'] as num).toInt(),
    vatRateId: json['vat_rate_id'] as String?,
    active: json['active'] as bool? ?? true,
  );

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

  DateTime get startsAt => DateTime(day.year, day.month, day.day)
      .add(Duration(minutes: startMinutes));
  DateTime get endsAt =>
      DateTime(day.year, day.month, day.day).add(Duration(minutes: endMinutes));
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

  factory GuestPassSale.fromJson(Map<String, dynamic> json) => GuestPassSale(
    passId: json['pass_id'] as String,
    memberId: json['member_id'] as String,
    reservationIds: [
      for (final r in json['reservation_ids'] as List? ?? const []) r as String,
    ],
    units: (json['units'] as num).toInt(),
    amountCents: (json['amount_cents'] as num).toInt(),
    invoiceId: json['invoice_id'] as String?,
    paymentEventId: json['payment_event_id'] as String?,
    replayed: json['replayed'] as bool? ?? false,
  );

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

/// The space's passes and their sale.
abstract interface class GuestPassRepository {
  Future<List<GuestPassOffer>> offers(String workspaceId);

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
    required Map<String, dynamic> guest,
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
