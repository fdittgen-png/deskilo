// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4172 (B) -- returns, corrections and counts behind one port. A return or a
// correction reverses ONE movement for a quantity and is bounded by what that
// movement still allows; a count records what was observed and waits for
// someone who may approve it. Each logical return, each line of it and each
// count has an identity of its own, kept by the form that made it, apart from
// the transport request id: a retry answers what was recorded. Quantities are
// exact decimal text.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// What a return follows.
enum StockReturnKind {
  /// Goods come back from a customer after a sale, to a real place.
  customer('customer'),

  /// Goods go back to the supplier of a delivery, from where they are now.
  supplier('supplier'),

  /// A movement undone by a movement back.
  correction('correction');

  const StockReturnKind(this.wire);

  /// The word the server reads.
  final String wire;
}

/// One thing already reversed on a movement.
class StockReversalEntry {
  const StockReversalEntry({
    required this.returnId,
    required this.lineId,
    required this.kind,
    required this.quantity,
    required this.movementId,
  });

  final String returnId;
  final String lineId;
  final String kind;
  final ExactQuantity quantity;

  /// The movement the reversal wrote.
  final String movementId;
}

/// A movement, how much of it was reversed and how much still can be.
class StockReversible {
  const StockReversible({
    required this.movementId,
    required this.reason,
    required this.quantity,
    required this.reversed,
    required this.remaining,
    required this.reversals,
  });

  final String movementId;
  final String reason;
  final ExactQuantity quantity;
  final ExactQuantity reversed;
  final ExactQuantity remaining;
  final List<StockReversalEntry> reversals;

  bool get fullyReversed => remaining <= ExactQuantity.zero;
}

/// One line of a return: the movement it reverses, how much, and the real
/// place the goods go back to (customer) or leave from (supplier); a
/// correction names none.
typedef StockReturnLineDraft = ({
  String lineId,
  String sourceMovementId,
  String quantity,
  String? locationId,
  String note,
});

/// What a return recorded: its identity and the movements it wrote.
typedef StockReturnResult = ({String returnId, List<String> movementIds, ExactQuantity remaining});

/// Where a count stands.
enum StockCountState {
  /// Counted, waiting for someone who may approve it.
  recorded,
  applied,
  rejected,
  cancelled,
  /// A value a newer server sent and this app does not know: shown as not known, and nothing is done on a guess.
  unknown;

  static StockCountState fromWire(String wire) => values.firstWhere(
    (s) => s != unknown && s.name == wire,
    orElse: () => StockCountState.unknown,
  );
}

/// What a person decides about a count.
enum StockCountDecision { apply, reject, cancel }

/// A count: what was observed against what the ledger held.
class StockCountRow {
  const StockCountRow({
    required this.countId,
    required this.itemId,
    required this.locationId,
    required this.observed,
    required this.baseline,
    required this.state,
    required this.stale,
    required this.authorMemberId,
    this.variantId,
    this.lotId,
    this.reason = '',
    this.decidedByMemberId,
    this.decidedAt,
    this.movementId,
  });

  final String countId;
  final String itemId;
  final String? variantId;
  final String? lotId;
  final String locationId;
  final ExactQuantity observed;
  final ExactQuantity baseline;
  final StockCountState state;

  /// Recorded, and the stock moved since it was counted: it cannot be
  /// applied, it is counted again.
  final bool stale;
  final String reason;
  final String authorMemberId;
  final String? decidedByMemberId;
  final DateTime? decidedAt;

  /// The adjustment an applied count made (none for a count with no
  /// difference).
  final String? movementId;

  ExactQuantity get difference => observed - baseline;
}

/// The returns and corrections of stock, and its counts.
/// What a count says: its identity, the scope counted, what was seen.
typedef StockCountDraft = ({
  String countId,
  String itemId,
  String locationId,
  String observed,
  String requestId,
  String? variantId,
  String? lotId,
  String reason,
});

abstract interface class StockReversals {
  /// What each movement allows to be reversed.
  Future<Map<String, StockReversible>> reversible(String workspaceId, List<String> movementIds);

  /// Makes (or answers again) one logical return.
  Future<StockReturnResult> makeReturn(
    String workspaceId,
    String returnId,
    StockReturnKind kind,
    List<StockReturnLineDraft> lines,
    String requestId,
  );

  /// The counts of the business, newest first.
  Future<List<StockCountRow>> counts(String workspaceId);

  /// Records a count of [itemId] at [locationId] (and its variant and lot);
  /// nothing moves.
  Future<void> recordCount(String workspaceId, StockCountDraft draft);

  /// Applies, rejects or cancels a count.
  Future<void> decideCount(
    String workspaceId,
    String countId,
    StockCountDecision decision,
    String requestId, {
    String note = '',
  });
}
