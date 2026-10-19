// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';

/// #2575 — what a member is told about a room the space rents (the answer of
/// `room_offer_v1`, 0496): until when it is rented and what one use costs
/// THEM. Never the cost to the space, the lessor or the contract: the server
/// does not send them.

enum RoomOfferUnit {
  halfDay('half_day'),
  hour('hour'),
  day('day');

  const RoomOfferUnit(this.wire);

  final String wire;

  static RoomOfferUnit of(String? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => halfDay);
}

class RoomOfferFee {
  const RoomOfferFee({required this.unit, required this.feeCents});

  final RoomOfferUnit unit;
  final int feeCents;
}

class RoomOfferView {
  const RoomOfferView({
    required this.currency,
    this.availableUntil,
    this.fees = const [],
  });

  factory RoomOfferView.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'room offer');
    return RoomOfferView(
      currency: r.stringOr('currency'),
      availableUntil: DateTime.tryParse(r.stringOr('available_until')),
      fees: [
        for (final f in r.list('fees'))
          RoomOfferFee(
            unit: RoomOfferUnit.of(JsonReader.of(f).stringOrNull('unit')),
            feeCents: JsonReader.of(f).integer('fee_cents'),
          ),
      ],
    );
  }

  final String currency;

  /// The last day the room can be booked, or null while open-ended.
  final DateTime? availableUntil;
  final List<RoomOfferFee> fees;
}

/// The offer of one room for the signed-in member.
abstract class RoomOfferRepository {
  /// Throws when the room is not open to the member.
  Future<RoomOfferView> fetch(String workspaceId, String officeId);
}
