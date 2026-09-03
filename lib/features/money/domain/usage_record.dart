// SPDX-License-Identifier: 0BSD
//
// #833 — what a check-out leaves behind.
//
// One row per counted reservation: the window as it was BOOKED, the time
// actually spent there, and what of that bills. The three are separate
// numbers on purpose — booking is the commitment, presence is the fact,
// and only a validated correction moves the first towards the second.
/// How the counted time was arrived at.
enum UsageBasis {
  /// The booked window, which is what bills until somebody says otherwise.
  reserved,

  /// An early departure that validators accepted: the booking's own end
  /// moved to the moment of check-out, so every total follows.
  corrected;

  static UsageBasis fromWire(String? wire) =>
      values.where((b) => b.name == wire).firstOrNull ?? UsageBasis.reserved;
}

class UsageRecord {
  const UsageRecord({
    required this.id,
    required this.memberId,
    required this.reservationId,
    required this.period,
    required this.reservedFrom,
    required this.reservedTo,
    required this.countedMinutes,
    required this.reservedMinutes,
    this.checkedInAt,
    this.checkedOutAt,
    this.actualMinutes,
    this.basis = UsageBasis.reserved,
    this.correctedFromMinutes,
    this.correctedAt,
    this.spaceLabel = '',
  });

  final String id;
  final String memberId;
  final String? reservationId;
  final String period;

  /// The window as BOOKED. A correction never rewrites these — they are
  /// the "before" half of "the record shows both values".
  final DateTime reservedFrom;
  final DateTime reservedTo;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;

  /// What bills.
  final int countedMinutes;
  final int reservedMinutes;

  /// Time actually present. Null when nobody came.
  final int? actualMinutes;
  final UsageBasis basis;
  final int? correctedFromMinutes;
  final DateTime? correctedAt;
  final String spaceLabel;

  /// Nobody checked in. Not a discount: the reserved window still bills.
  bool get isNoShow => checkedInAt == null;

  bool get isCorrected => basis == UsageBasis.corrected;

  /// Left before the booking ended, and it has not been corrected yet —
  /// the one case where there is something to ask for.
  bool get leftEarly =>
      !isCorrected &&
      actualMinutes != null &&
      checkedOutAt != null &&
      actualMinutes! < reservedMinutes;

  /// Minutes that would stop billing if a correction were accepted.
  int get reducibleMinutes =>
      leftEarly ? reservedMinutes - actualMinutes! : 0;

  static UsageRecord fromJson(Map<String, dynamic> json) => UsageRecord(
        id: json['id'] as String,
        memberId: json['member_id'] as String,
        reservationId: json['reservation_id'] as String?,
        period: json['period'] as String? ?? '',
        reservedFrom: DateTime.parse(json['reserved_from'] as String).toLocal(),
        reservedTo: DateTime.parse(json['reserved_to'] as String).toLocal(),
        checkedInAt: json['checked_in_at'] == null
            ? null
            : DateTime.parse(json['checked_in_at'] as String).toLocal(),
        checkedOutAt: json['checked_out_at'] == null
            ? null
            : DateTime.parse(json['checked_out_at'] as String).toLocal(),
        countedMinutes: (json['counted_minutes'] as num?)?.toInt() ?? 0,
        reservedMinutes: (json['reserved_minutes'] as num?)?.toInt() ?? 0,
        actualMinutes: (json['actual_minutes'] as num?)?.toInt(),
        basis: UsageBasis.fromWire(json['basis'] as String?),
        correctedFromMinutes:
            (json['corrected_from_minutes'] as num?)?.toInt(),
        correctedAt: json['corrected_at'] == null
            ? null
            : DateTime.parse(json['corrected_at'] as String).toLocal(),
        spaceLabel: json['space_label'] as String? ?? '',
      );
}

/// "3 h 20" — the shape every usage number is read in. Minutes alone are
/// unreadable at this scale and decimal hours lie about the quarter.
String usageDuration(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest min';
  if (rest == 0) return '$hours h';
  return '$hours h ${rest.toString().padLeft(2, '0')}';
}
