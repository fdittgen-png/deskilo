// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';
import '../../../core/time/date_text.dart';
import 'room_level_kind.dart';

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
    this.audienceAll = false,
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
      audienceAll: r.boolOr('audience_all', fallback: false),
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

  /// Every active member may book the room, besides the named [audience].
  final bool audienceAll;
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

/// A level with its kind, as the rentals screen lists them.
class RoomLevel {
  const RoomLevel({required this.id, required this.name, required this.kind});

  factory RoomLevel.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'room level');
    return RoomLevel(
      id: r.string('id'),
      name: r.stringOr('name'),
      kind: LevelKind.of(r.stringOrNull('kind')),
    );
  }

  final String id;
  final String name;
  final LevelKind kind;
}

/// A room of an external level, with whether it already has a rental.
class RentableRoom {
  const RentableRoom({
    required this.officeId,
    required this.name,
    required this.levelName,
    required this.rented,
  });

  factory RentableRoom.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'rentable room');
    return RentableRoom(
      officeId: r.string('office_id'),
      name: r.stringOr('name'),
      levelName: r.stringOr('level_name'),
      rented: r.boolOr('rented', fallback: false),
    );
  }

  final String officeId;
  final String name;
  final String levelName;
  final bool rented;
}

/// What the rentals screen reads in one answer.
class RoomRentalsOverview {
  const RoomRentalsOverview({
    this.rentals = const [],
    this.levels = const [],
    this.rooms = const [],
  });

  factory RoomRentalsOverview.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'room rentals');
    return RoomRentalsOverview(
      rentals: [for (final x in r.list('rentals')) RoomRental.fromJson(x)],
      levels: [for (final x in r.list('levels')) RoomLevel.fromJson(x)],
      rooms: [for (final x in r.list('rooms')) RentableRoom.fromJson(x)],
    );
  }

  final List<RoomRental> rentals;
  final List<RoomLevel> levels;
  final List<RentableRoom> rooms;
}

/// A rental to record or change; the audience and the fees follow it.
class RoomRentalCommand {
  const RoomRentalCommand({
    required this.officeId,
    required this.supplierId,
    required this.availableFrom,
    required this.status,
    this.availableUntil,
    this.costKind = 'fixed_per_period',
    this.costCents = 0,
    this.period = 'month',
    this.revision = 0,
    this.audienceAll = false,
    this.audience = const [],
    this.fees = const [],
  });

  final String officeId;
  final String supplierId;
  final DateTime availableFrom;
  final DateTime? availableUntil;
  final RoomRentalStatus status;
  final String costKind;
  final int costCents;
  final String period;
  final int revision;
  final bool audienceAll;
  final List<RoomAudienceEntry> audience;
  final List<RoomFee> fees;
}

/// The rented rooms of one space; every write goes through an RPC.
/// A plan of the space a room may be opened to.
class RoomPlan {
  const RoomPlan({required this.id, required this.name});

  final String id;
  final String name;
}

abstract class RoomRentalRepository {
  Future<RoomRentalsOverview> fetchOverview(String workspaceId);

  /// The active plans a room can be opened to, by name.
  Future<List<RoomPlan>> fetchPlans(String workspaceId);

  Future<void> setLevelKind(String workspaceId, String levelId, LevelKind kind);

  /// Saves the rental, then its audience and fees; returns it as the server
  /// now has it.
  Future<RoomRental> saveRental(String workspaceId, RoomRentalCommand command);

  /// What the signed-in member would pay for [officeId] and until when.
  Future<RoomOffer> fetchOffer(String workspaceId, String officeId);
}
