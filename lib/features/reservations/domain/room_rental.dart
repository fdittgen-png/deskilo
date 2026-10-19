// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';
import '../../../core/time/date_text.dart';

/// #2568 — a room the space rents (`room_rentals`, 0496). The server owns
/// every rule and refuses on every booking path; these are the shapes it
/// answers with, and the window rule the client can show before asking.

/// The permission that manages rentals, audiences and fees.
const roomRentalManagePermission = 'manageSites';

enum RoomRentalStatus {
  draft('draft'),
  active('active'),
  ended('ended');

  const RoomRentalStatus(this.wire);

  final String wire;

  static RoomRentalStatus of(String? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => draft);
}

enum RoomFeeUnit {
  halfDay('half_day'),
  hour('hour'),
  day('day');

  const RoomFeeUnit(this.wire);

  final String wire;

  static RoomFeeUnit of(String? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => halfDay);
}

/// Why a period cannot be booked in a rented room. The wording stays the
/// server's: a refusal reads the same on every path.
enum RoomWindowRefusal { notRented, beforeStart, afterEnd }

/// One audience entry: exactly one of a role, a plan or a member.
class RoomAudienceEntry {
  const RoomAudienceEntry({this.roleId, this.planId, this.memberId});

  factory RoomAudienceEntry.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'room audience');
    return RoomAudienceEntry(
      roleId: r.stringOrNull('role_id'),
      planId: r.stringOrNull('plan_id'),
      memberId: r.stringOrNull('member_id'),
    );
  }

  final String? roleId;
  final String? planId;
  final String? memberId;

  Map<String, Object?> toJson() => {
    if (roleId != null) 'role_id': roleId,
    if (planId != null) 'plan_id': planId,
    if (memberId != null) 'member_id': memberId,
  };
}

/// What one use costs the member; the audience entry is set when the fee is
/// for that entry only.
class RoomFee {
  const RoomFee({
    required this.unit,
    required this.feeCents,
    this.audience = const RoomAudienceEntry(),
  });

  factory RoomFee.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'room fee');
    return RoomFee(
      unit: RoomFeeUnit.of(r.stringOrNull('unit')),
      feeCents: r.integer('fee_cents'),
      audience: RoomAudienceEntry.fromJson(raw),
    );
  }

  final RoomFeeUnit unit;
  final int feeCents;
  final RoomAudienceEntry audience;

  Map<String, Object?> toJson() => {
    'unit': unit.wire,
    'fee_cents': feeCents,
    ...audience.toJson(),
  };
}

/// The rental as its managers read it, cost and lessor included.
class RoomRental {
  const RoomRental({
    required this.id,
    required this.revision,
    required this.officeId,
    required this.officeName,
    required this.supplierId,
    required this.supplierName,
    required this.availableFrom,
    required this.status,
    this.availableUntil,
    this.costKind = 'fixed_per_period',
    this.costCents = 0,
    this.period = 'month',
    this.currency = '',
    this.audience = const [],
    this.fees = const [],
  });

  factory RoomRental.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'room rental');
    return RoomRental(
      id: r.string('id'),
      revision: r.integer('revision'),
      officeId: r.string('office_id'),
      officeName: r.stringOr('office_name'),
      supplierId: r.string('supplier_id'),
      supplierName: r.stringOr('supplier_name'),
      availableFrom: DateTime.parse(r.string('available_from')),
      availableUntil: DateTime.tryParse(r.stringOr('available_until')),
      status: RoomRentalStatus.of(r.stringOrNull('status')),
      costKind: r.stringOr('cost_kind', 'fixed_per_period'),
      costCents: r.intOrNull('cost_cents') ?? 0,
      period: r.stringOr('period', 'month'),
      currency: r.stringOr('currency'),
      audience: [
        for (final a in r.list('audience')) RoomAudienceEntry.fromJson(a),
      ],
      fees: [for (final f in r.list('fees')) RoomFee.fromJson(f)],
    );
  }

  final String id;
  final int revision;
  final String officeId;
  final String officeName;
  final String supplierId;
  final String supplierName;

  /// First day the room is rented.
  final DateTime availableFrom;

  /// Last day the room is rented, inclusive; null while open-ended.
  final DateTime? availableUntil;
  final RoomRentalStatus status;
  final String costKind;
  final int costCents;
  final String period;
  final String currency;
  final List<RoomAudienceEntry> audience;
  final List<RoomFee> fees;

  /// Why a booking from [startsOn] to [lastDay] (workspace-local calendar
  /// days, the last day being the one the booking ends on) is outside the
  /// rental, or null when it is inside. Mirrors the server's rule for showing
  /// the reason early; the server decides.
  RoomWindowRefusal? windowRefusal(DateTime startsOn, DateTime lastDay) {
    if (status != RoomRentalStatus.active) return RoomWindowRefusal.notRented;
    if (isoDay(startsOn).compareTo(isoDay(availableFrom)) < 0) {
      return RoomWindowRefusal.beforeStart;
    }
    final until = availableUntil;
    if (until != null && isoDay(lastDay).compareTo(isoDay(until)) > 0) {
      return RoomWindowRefusal.afterEnd;
    }
    return null;
  }
}

/// What a member is shown about a room: its window and what a use costs
/// THEM. Never the cost to the space, the lessor or the contract.
class RoomOffer {
  const RoomOffer({
    required this.officeId,
    required this.availableFrom,
    required this.currency,
    this.availableUntil,
    this.fees = const [],
  });

  factory RoomOffer.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'room offer');
    return RoomOffer(
      officeId: r.string('office_id'),
      availableFrom: DateTime.parse(r.string('available_from')),
      availableUntil: DateTime.tryParse(r.stringOr('available_until')),
      currency: r.stringOr('currency'),
      fees: [for (final f in r.list('fees')) RoomFee.fromJson(f)],
    );
  }

  final String officeId;
  final DateTime availableFrom;
  final DateTime? availableUntil;
  final String currency;
  final List<RoomFee> fees;

  int? feeFor(RoomFeeUnit unit) {
    for (final f in fees) {
      if (f.unit == unit) return f.feeCents;
    }
    return null;
  }
}
