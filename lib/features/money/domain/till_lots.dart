// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 / #4436 -- the lots a till may sell an item from (counter_item_lots_v1): each lot's code, date and quantity on
// hand in the item's inventory unit, and the ports that read them.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

/// #4366 -- a lot of an item on hand where a counter sale takes from: its code, its date, what is on hand (in the item's
/// inventory unit) and whether it is past its date (shown, never offered).
class TillLot {
  const TillLot({required this.id, required this.code, required this.quantity, this.expiresOn, this.expired = false});

  factory TillLot.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_item_lots');
    return TillLot(
      id: r.string('lot_id'),
      code: r.stringOr('code'),
      quantity: r.stringOr('quantity'),
      expiresOn: switch (r.stringOrNull('expires_on')) { final d? => DateTime.tryParse(d), null => null },
      expired: r.boolOr('expired', fallback: false),
    );
  }

  final String id;
  final String code;
  final String quantity;
  final DateTime? expiresOn;
  final bool expired;
}

/// #4366 -- the lots a till may sell an item from (`counter_item_lots_v1`): the first to expire first. [tillId] names
/// the till, whose selling place (and every place below it) holds them; without one, the business's selling place.
abstract interface class TillLotsPort {
  Future<List<TillLot>> lots(String workspaceId, String itemId, {String? tillId});
}

/// A till that reads its lots through a port of its own (the Demo's).
abstract interface class TillLotsSource {
  TillLotsPort get lotsPort;
}

/// The lots in the server's answer.
List<TillLot> tillLotsOf(Object? json) => [
  for (final l in JsonReader.of(json, context: 'counter_item_lots').list('lots')) TillLot.fromJson(l),
];
