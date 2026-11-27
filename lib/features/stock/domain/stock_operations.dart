// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4170 (B) -- the stock commands the screens run, behind one port: a transfer
// inside a site, a transfer between sites in two steps (loaded, then received
// in all or in part), goods taken out for use or as a loss, the lots a take-out
// proposes, and the transfers still on their way. A refusal is a typed failure
// the screen shows under its field; a request id that is retried answers what
// it answered and does nothing twice. Quantities are exact decimal text.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// One line of a command: [quantity] (in [unit], or the item's inventory unit)
/// of one item, taken from [fromLocationId] and, for a transfer, put on
/// [toLocationId].
class StockLineDraft {
  const StockLineDraft({
    required this.itemId,
    required this.quantity,
    required this.fromLocationId,
    this.toLocationId,
    this.variantId,
    this.lotId,
    this.unit,
    this.expiredAck = false,
  });

  final String itemId;
  final String quantity;
  final String fromLocationId;
  final String? toLocationId;
  final String? variantId;
  final String? lotId;
  final String? unit;

  /// The operator knows this lot is past its date and takes it anyway.
  final bool expiredAck;

  Map<String, Object?> toJson() => {
    'item_id': itemId,
    'quantity': quantity,
    'from': fromLocationId,
    'to': ?toLocationId,
    'variant_id': ?variantId,
    'lot_id': ?lotId,
    'unit': ?unit,
    if (expiredAck) 'expired_ack': true,
  };
}

/// Why goods leave the stock without a sale.
enum StockTakeOutReason {
  /// Used up by the business itself.
  consumption,

  /// Written off: broken, spoiled, lost.
  loss,
}

/// Why goods were written off, by the server's key (`stock_movements.loss_cause`). Goods the business uses itself are
/// not a loss: they leave as [StockTakeOutReason.consumption].
enum StockLossCause {
  expired('expired'),
  damaged('damaged'),
  spoiled('spoiled'),
  missing('missing'),
  other('other');

  const StockLossCause(this.wire);

  final String wire;
}

/// The longest note a loss carries.
const int kStockLossNoteMaxLength = 500;

/// What a loss says beside its lines: why the goods were lost, and a note when the person wrote one.
class StockLoss {
  const StockLoss({required this.cause, this.note = ''});

  final StockLossCause cause;
  final String note;

  /// The note as it is sent: trimmed, and none when it is empty.
  String? get noteOrNull => note.trim().isEmpty ? null : note.trim();
}

/// What is wrong with a loss as it was filled in.
enum StockLossProblem { causeMissing, noteTooLong }

/// The first problem of a loss with [cause] and [note], or none: a loss says why, and its note has a length.
StockLossProblem? checkStockLoss(StockLossCause? cause, String note) => cause == null
    ? StockLossProblem.causeMissing
    : note.trim().length > kStockLossNoteMaxLength
    ? StockLossProblem.noteTooLong
    : null;

/// What one command answered; a retried request id answers the same.
typedef StockCommandResult = ({
  String requestId,
  int movements,
  String? transferId,
  String? status,
});

/// One line of a transfer: what was loaded and how much of it has arrived.
class StockTransferLine {
  const StockTransferLine({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.loaded,
    required this.received,
    this.variantId,
    this.lotId,
  });

  final String id;
  final String itemId;
  final String itemName;
  final String unit;
  final String? variantId;
  final String? lotId;
  final ExactQuantity loaded;
  final ExactQuantity received;

  /// What is still on its way.
  ExactQuantity get inTransit => loaded - received;
}

/// A transfer between two sites: loaded at the source, on its way, received.
class StockTransfer {
  const StockTransfer({
    required this.id,
    required this.fromLocationId,
    required this.fromCode,
    required this.toLocationId,
    required this.toCode,
    required this.status,
    required this.loadedAt,
    required this.revision,
    required this.lines,
  });

  final String id;
  final String fromLocationId;
  final String fromCode;
  final String toLocationId;
  final String toCode;

  /// `loaded`, `partly_received` or `received`.
  final String status;
  final DateTime loadedAt;
  final int revision;
  final List<StockTransferLine> lines;

  bool get open => status != 'received';
}

/// What to receive of one line of a transfer, and where it goes (the
/// transfer's destination when [toLocationId] is null).
typedef StockReceiveDraft = ({String lineId, String quantity, String? toLocationId});

/// One lot a take-out proposes, soonest expiry first.
class StockLotProposal {
  const StockLotProposal({
    required this.lotId,
    required this.lotCode,
    required this.expiresOn,
    required this.expired,
    required this.available,
    required this.take,
  });

  /// Null for what is held without a lot.
  final String? lotId;
  final String? lotCode;
  final String? expiresOn;

  /// Past its date today: taking it needs the operator's acknowledgement.
  final bool expired;
  final ExactQuantity available;
  final ExactQuantity take;
}

/// The lots a quantity would be taken from, and what no lot holds.
class StockProposal {
  const StockProposal({required this.lots, required this.short});

  final List<StockLotProposal> lots;
  final ExactQuantity short;
}

/// The goods that are on their way, the commands that move stock, and the
/// proposal a take-out starts from.
abstract interface class StockOperations {
  /// The transfers of the business that are not fully received, oldest first.
  Future<List<StockTransfer>> openTransfers(String workspaceId);

  /// Moves goods between two places of one site, at once.
  Future<StockCommandResult> transfer(
    String workspaceId,
    List<StockLineDraft> lines,
    String requestId,
  );

  /// Loads goods from one place onto the way to [toLocationId], a place of
  /// another site; they stay in transit until received.
  Future<StockCommandResult> load(
    String workspaceId,
    String toLocationId,
    List<StockLineDraft> lines,
    String requestId,
  );

  /// Receives what was loaded, all or in part.
  Future<StockCommandResult> receive(
    String workspaceId,
    String transferId,
    List<StockReceiveDraft> lines,
    String requestId,
  );

  /// Takes goods out for [reason]; the feature stockTakeOut must be on. A loss says why ([loss]): one without its
  /// cause is refused, and nothing moves.
  Future<StockCommandResult> takeOut(
    String workspaceId,
    StockTakeOutReason reason,
    List<StockLineDraft> lines,
    String requestId, {
    StockLoss? loss,
  });

  /// The lots [quantity] of an item would be taken from at one place.
  Future<StockProposal> proposal(
    String workspaceId, {
    required String itemId,
    required String locationId,
    required String quantity,
    String? variantId,
  });
}
