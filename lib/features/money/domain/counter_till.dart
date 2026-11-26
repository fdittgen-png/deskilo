// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 (CS4) -- the till: the counter receipt as the screen needs it. The server (#4184/#4185) prices a basket
// (`counter_receipt_draft_v1`), numbers and takes tenders in ONE command (`counter_receipt_finalize_v1`) and says
// whether the country allows any of it (`counter_readiness_v1`); this file is what it answers and the port the till
// uses. Amounts are MINOR units; a quantity is an exact decimal string; nothing here prices a line.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

import 'counter_receipt_document.dart';
import 'till_lots.dart';
import 'till_quantity.dart';

export 'till_lots.dart';
export 'till_returns.dart';

/// One operation of the counter in the business's country, under the case the owner declared, with the evidence the
/// registry names for it (#4184): its specification, version and effective date, the adapter, the proof, and whether
/// a tax professional confirmed it.
class TillOperation {
  const TillOperation({
    required this.operation,
    required this.outcome,
    required this.reason,
    required this.note,
    this.specification = '',
    this.specificationVersion = '',
    this.effectiveFrom = '',
    this.adapter = '',
    this.evidence = '',
    this.confirmed = false,
  });

  /// `issue_receipt`, `correct_receipt`, `reconcile_tender`, `sign_fiscal`, `export_fiscal`.
  final String operation;

  /// `supported` or `unavailable`.
  final String outcome;

  /// Why it is unavailable: `unavailable` (the registry says so) or `adapter_missing`; empty when supported.
  final String reason;
  final String note;

  /// The authoritative text the row rests on, its version and the day it took effect.
  final String specification;
  final String specificationVersion;
  final String effectiveFrom;

  /// The implementation that carries the operation; empty when none does.
  final String adapter;

  /// What proves the row: the tests of the implementation, or why there is none.
  final String evidence;

  /// Whether a tax professional confirmed the row: false for every row today.
  final bool confirmed;

  bool get supported => outcome == 'supported';

  /// The same operation with the registry's [text] of evidence.
  TillOperation withEvidence(String text) => TillOperation(
    operation: operation,
    outcome: outcome,
    reason: reason,
    note: note,
    specification: specification,
    specificationVersion: specificationVersion,
    effectiveFrom: effectiveFrom,
    adapter: adapter,
    evidence: text,
    confirmed: confirmed,
  );

  factory TillOperation.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_readiness.operations');
    return TillOperation(
      operation: r.string('operation'),
      outcome: r.string('outcome'),
      reason: r.stringOr('reason'),
      note: r.stringOr('note'),
      specification: r.textOrAbsent('specification') ?? '',
      specificationVersion: r.textOrAbsent('specification_version') ?? '',
      effectiveFrom: r.textOrAbsent('effective_from') ?? '',
      adapter: r.textOrAbsent('adapter') ?? '',
      evidence: r.textOrAbsent('evidence') ?? '',
      confirmed: r.isTrue('confirmed'),
    );
  }
}

/// Whether the till may sell here: `ready` needs issuing a receipt and reconciling a tender both supported.
class TillReadiness {
  const TillReadiness({required this.country, required this.fiscalObligation, required this.ready, required this.operations});

  final String country;

  /// `none` or `register_required` (the owner's declaration, `counter.fiscal_obligation`).
  final String fiscalObligation;
  final bool ready;
  final List<TillOperation> operations;

  /// The registry names no operation for this country under this declaration: nothing is supported, nothing guessed.
  bool get unknownCountry => operations.isEmpty;

  /// The operations that block selling: the ones the till needs and the country does not allow.
  List<TillOperation> get blocking => [
    for (final o in operations)
      if (!o.supported && (o.operation == 'issue_receipt' || o.operation == 'reconcile_tender')) o,
  ];

  factory TillReadiness.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_readiness');
    return TillReadiness(
      country: r.stringOr('country'),
      fiscalObligation: r.stringOr('fiscal_obligation', 'register_required'),
      ready: r.boolOr('ready', fallback: false),
      operations: [for (final o in r.listOrAbsent('operations')) TillOperation.fromJson(o)],
    );
  }
}

/// A line of the basket as the till sends it: an item and an exact quantity; the server prices it.
class TillLine {
  const TillLine({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unit,
    this.pieces = const [],
    this.ageConfirmed,
    this.depositFor,
    this.price,
    this.priceReason,
    this.discount,
    this.lot,
    this.returned = false,
  });

  final String itemId;
  final String name;

  /// An exact decimal string (`^[0-9]{1,12}(\.[0-9]{1,6})?$`, above zero): a weighed quantity is a normal decimal.
  final String quantity;
  final String unit;

  /// #4436 -- the tags of the pieces scanned into this line, for an item tracked piece by piece: the sale takes
  /// exactly these pieces, and the server refuses a quantity that is not their number.
  final List<String> pieces;

  /// The age the operator confirmed the customer has for this line (the item's minimum), kept on the line; null when
  /// the item has no age limit.
  final int? ageConfirmed;

  /// The item whose deposit this line is: it follows that line's quantity and goes with it. Null for an ordinary line.
  final String? depositFor;

  /// #4476 -- a price other than the item's (an exact decimal with a point), set by someone with the right to change a
  /// price at the till, and why; null sells at the item's price. The server refuses it without the right or the reason.
  final String? price;
  final String? priceReason;

  /// The longest reason a changed price keeps, as the server takes it.
  static const priceReasonMaxLength = 200;

  /// #4476 -- a discount in percent off the item's price (an exact decimal with a point), within the business's limit.
  final String? discount;

  /// The line at the item's price again, or at [price] for [reason], or with [discount] percent off: one of the three.
  TillLine withPricing({String? price, String? reason, String? discount}) => TillLine(
    itemId: itemId,
    name: name,
    quantity: quantity,
    unit: unit,
    pieces: pieces,
    ageConfirmed: ageConfirmed,
    depositFor: depositFor,
    price: price,
    priceReason: price == null ? null : reason,
    discount: price == null ? discount : null,
    lot: lot,
    returned: returned,
  );

  /// #4366 -- the lot the seller chose to sell from; null leaves the server to take the one that expires first.
  final TillLot? lot;

  /// #4478 -- a deposit brought back: the deposit item at this quantity, taken off the sale (the server negates it).
  final bool returned;

  /// The line sold from [chosen], or (null) from the lot that expires first again.
  TillLine withLot(TillLot? chosen) => TillLine(
    itemId: itemId,
    name: name,
    quantity: quantity,
    unit: unit,
    pieces: pieces,
    ageConfirmed: ageConfirmed,
    depositFor: depositFor,
    price: price,
    priceReason: priceReason,
    discount: discount,
    lot: chosen,
    returned: returned,
  );

  /// The line at quantity [q]. Named pieces stay only when [q] is exactly their number: any other quantity (a tap on the item's key, a
  /// typed number) leaves the line a plain quantity of the item, because the server refuses a quantity that is not the number of its
  /// named pieces (DKG25) and would say so only after the cash was taken.
  TillLine withQuantity(String q) => TillLine(
    itemId: itemId,
    name: name,
    quantity: q,
    unit: unit,
    pieces: tillQuantityOf(q) == '${pieces.length}' ? pieces : const [],
    ageConfirmed: ageConfirmed,
    depositFor: depositFor,
    price: price,
    priceReason: priceReason,
    discount: discount,
    lot: lot,
    returned: returned,
  );

  /// The line with the piece tagged [tag] added: one more, named (a piece names its own lot).
  TillLine withPiece(String tag) =>
      TillLine(
        itemId: itemId,
        name: name,
        quantity: '${pieces.length + 1}',
        unit: unit,
        pieces: [...pieces, tag],
        ageConfirmed: ageConfirmed,
        depositFor: depositFor,
        price: price,
        priceReason: priceReason,
        discount: discount,
        returned: returned,
      );

  Map<String, Object?> toJson() => {
    'item_id': itemId,
    'quantity': quantity,
    if (pieces.isNotEmpty) 'units': [for (final t in pieces) {'tag': t}],
    'unit_price': ?price,
    'price_reason': ?priceReason,
    'discount_percent': ?discount,
    if (pieces.isEmpty && lot != null) 'lot_id': lot!.id,
    if (returned) 'returned': true,
  };
}

/// #4436 -- what a code scanned at the till rings up: an item, one piece of an item by its tag, or nothing.
sealed class TillScan {
  const TillScan();
}

/// An item: one more of it, as a tap on its key.
class TillScanItem extends TillScan {
  const TillScanItem(this.key);

  final TillKey key;
}

/// One piece of an item tracked piece by piece, by its tag: the sale takes that piece.
class TillScanPiece extends TillScan {
  const TillScanPiece(this.key, this.tag);

  final TillKey key;
  final String tag;
}

/// A code that names nothing the till sells.
class TillScanUnknown extends TillScan {
  const TillScanUnknown(this.code);

  final String code;
}

/// The server sends totals as strings and per-line amounts as integers: both read as minor units.
int _minor(JsonReader r, String key) => int.parse('${r.raw(key)}');

/// What the basket totals to, in minor units.
class TillTotals {
  const TillTotals({required this.netMinor, required this.taxMinor, required this.grossMinor, required this.currency});

  final int netMinor;
  final int taxMinor;
  final int grossMinor;
  final String currency;

  factory TillTotals.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_receipt.totals');
    return TillTotals(
      netMinor: _minor(r, 'net_minor'),
      taxMinor: _minor(r, 'tax_minor'),
      grossMinor: _minor(r, 'gross_minor'),
      currency: r.stringOr('currency'),
    );
  }
}

/// A priced line of the draft, as the server froze it.
class TillPricedLine {
  const TillPricedLine({required this.label, required this.grossMinor, required this.quantity});

  final String label;
  final int grossMinor;
  final String quantity;
}

/// The priced basket: nothing numbered, nothing taken.
class TillDraft {
  const TillDraft({required this.receiptId, required this.revision, required this.totals, required this.lines, required this.issueReceipt});

  final String receiptId;
  final int revision;
  final TillTotals totals;
  final List<TillPricedLine> lines;

  /// `supported`, `unavailable`, `adapter_missing` or `no_row`.
  final String issueReceipt;

  factory TillDraft.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_receipt_draft');
    final lines = <TillPricedLine>[];
    for (final l in r.listOrAbsent('lines')) {
      final x = JsonReader.of(l, context: 'counter_receipt_draft.lines');
      lines.add(TillPricedLine(label: x.stringOr('label'), grossMinor: x.intOrNull('amount_cents') ?? 0, quantity: x.objectOrAbsent('commercial').stringOr('quantity')));
    }
    return TillDraft(
      receiptId: r.string('receipt_id'),
      revision: r.integer('revision'),
      totals: TillTotals.fromJson(r.raw('totals')),
      lines: lines,
      issueReceipt: r.stringOr('issue_receipt', 'supported'),
    );
  }
}

/// A tender: `cash` or `other`, an exact amount in minor units; or (#4185) an accepted card authorization of the sale,
/// named by its [tenderId] (the server knows its amount).
class TillTender {
  const TillTender({required this.kind, required this.amountMinor, this.tenderId});

  final String kind;
  final int amountMinor;
  final String? tenderId;

  Map<String, Object?> toJson() => tenderId != null ? {'tender_id': tenderId} : {'kind': kind, 'amount_minor': amountMinor};
}

/// #4185 -- a card authorization asked of the terminal for a sale: the server's record of it, before any answer.
class TillCardAsked {
  const TillCardAsked({required this.tenderId, required this.providerKey, required this.amountMinor});

  final String tenderId;

  /// The key the authorization is asked under: typed on the terminal, and what its journal is searched for.
  final String providerKey;
  final int amountMinor;

  factory TillCardAsked.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_tender_request');
    return TillCardAsked(tenderId: r.string('tender_id'), providerKey: r.stringOr('provider_key'), amountMinor: r.intOrNull('amount_minor') ?? 0);
  }
}

/// #4436 -- a track ID a goods line took: a lot (its code as received, the quantity taken from it, in the item's
/// inventory unit) or a piece (its tag).
class TillTrack {
  const TillTrack({required this.kind, required this.code, this.quantity});

  /// `lot` or `piece`.
  final String kind;

  /// The lot's code as received (else its label code), or the piece's tag; empty when the lot has no code.
  final String code;

  /// The quantity taken from a lot; null for a piece.
  final String? quantity;

  bool get isPiece => kind == 'piece';

  factory TillTrack.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_receipt_finalize.lines.tracks');
    return TillTrack(kind: r.string('kind'), code: r.stringOr('code'), quantity: r.stringOrNull('quantity'));
  }
}

/// #4436 -- what one goods line of a sale took, as the receipt froze it.
class TillSoldLine {
  const TillSoldLine({required this.lineNo, required this.tracks});

  /// The line's place on the receipt, from 1: the basket's line of the same place.
  final int lineNo;
  final List<TillTrack> tracks;

  factory TillSoldLine.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_receipt_finalize.lines');
    return TillSoldLine(lineNo: r.integer('line_no'), tracks: [for (final t in r.listOrAbsent('tracks')) TillTrack.fromJson(t)]);
  }
}

/// A sale made: its number and totals.
class TillSold {
  const TillSold({required this.receiptId, required this.number, required this.totals, this.lines = const []});

  final String receiptId;
  final String number;
  final TillTotals totals;

  /// #4436 -- the goods lines and the track IDs each took; a line that is not goods is not listed.
  final List<TillSoldLine> lines;

  /// The track IDs the basket's line [lineNo] (from 1) took; empty when it took none.
  List<TillTrack> tracksOf(int lineNo) => [
    for (final l in lines)
      if (l.lineNo == lineNo) ...l.tracks,
  ];

  factory TillSold.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_receipt_finalize');
    return TillSold(
      receiptId: r.string('receipt_id'),
      number: r.string('number'),
      totals: TillTotals.fromJson(r.raw('totals')),
      lines: [for (final l in r.listOrAbsent('lines')) TillSoldLine.fromJson(l)],
    );
  }
}

/// The till's server: readiness, a priced draft, and the one command that numbers a receipt and takes its tenders.
/// A refusal arrives as the server's own error (`knownRefusalText` says it in words).
abstract interface class TillPort {
  Future<TillReadiness> readiness(String workspaceId);

  /// Prices [lines]; [receiptId] and [expectedRevision] replace the lines of an open draft, both null make a new one.
  /// [tillId] names the till the sale is made on: a business that runs till sessions needs one with an open session.
  Future<TillDraft> draft(String workspaceId, {required String requestId, required List<TillLine> lines, String? receiptId, int? expectedRevision, String? tillId});

  Future<TillSold> finalize(String workspaceId, {required String requestId, required String receiptId, required int expectedRevision, required List<TillTender> tenders});

  /// #4184 -- the finalized receipt [receiptId] as its frozen document, read by the versioned reader.
  Future<CounterReceiptDocument> receipt(String workspaceId, String receiptId);
  /// #4185 -- records that a card authorization of [amountMinor] is asked for the open draft [receiptId].
  Future<TillCardAsked> requestCard(String workspaceId, {required String requestId, required String receiptId, required int amountMinor});

  /// #4185 -- records the terminal's answer to [tenderId]: `accepted`, `refused` or `unknown`; answers the state and
  /// whether the money waits for a reconciliation (`needed`).
  Future<({String state, String? reconciliation})> resolveCard(String workspaceId, {required String requestId, required String tenderId, required String outcome, String providerRef = ''});
}

/// #4366 -- an item the till offers as a key: what a tap rings up.
class TillKey {
  const TillKey({
    required this.id,
    required this.name,
    required this.unit,
    this.grossMinor,
    this.category,
    this.colour,
    this.minAge,
    this.weighed = false,
    this.depositItemId,
  });

  final String id;
  final String name;
  final String unit;

  /// #4373 -- the item's price, gross, minor units of one unit, when the route knows it: what the till falls back on when it sells
  /// offline. The server prices every online sale; this is never used for one.
  final int? grossMinor;

  /// The group of keys it sits under (the item's till category); null for the keys without one.
  final String? category;

  /// The key's colour as `#rrggbb`, or null for the default.
  final String? colour;

  /// The age a customer must be, confirmed by the operator on the line; null when there is no limit.
  final int? minAge;

  /// Sold by weight: the key asks the weight in [unit] instead of ringing up one.
  final bool weighed;

  /// The item whose deposit is added with this one, or null.
  final String? depositItemId;
}

/// #4476 -- a copy of a finalized receipt, printed again: counted by the server and never numbered again. Its number
/// among the copies (1, 2, ...) is what the copy shows.
abstract interface class TillCopyPort {
  Future<int> copy(String workspaceId, {required String requestId, required String receiptId});
}

/// The copy's number in the server's answer (`copy_no`).
int tillCopyNumberOf(Object? json) => JsonReader.of(json, context: 'counter_receipt_copy').integer('copy_no');
