// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4185 (CS2) -- the counter's book: the receipts a till made, as the screen that corrects them needs them. A sale is
// never edited: a correction is a NEW receipt that cites it (`counter_receipt_correct_v1`), money given back is a refund
// of that correction (`counter_refund_v1`), and goods taken back are a return of that correction (`counter_goods_return_v1`).
// Each is its own authorized act with what is left of it named here; the server enforces every bound again. A card
// authorization whose answer was lost waits here, with its reference, for someone who may see the finances to settle it
// (`counter_tender_resolve_v1`); a sale whose card was accepted is completed from here under the same receipt
// (`counter_receipt_finalize_v1`), never charged a second time. Amounts are MINOR units; quantities exact decimal text.
import 'dart:math' as math;

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

import 'till_quantity.dart';

/// The decimals a quantity keeps, and its unit in that many places.
const int _decimals = 6;
final int _scale = math.pow(10, _decimals).toInt();

/// The longest reason a correction or a return carries.
// not-mirrored: the server cuts a longer reason to 200 characters (left()), it does not refuse it
const int counterReasonMaxLength = 200;
final RegExp _shape = RegExp(r'^[0-9]{1,12}(\.[0-9]{1,6})?$');

/// [text] (an exact quantity) in millionths; 0 when it is not one.
int counterQuantityUnits(String text) {
  final t = text.trim();
  if (!_shape.hasMatch(t)) return 0;
  final parts = t.split('.');
  final fraction = (parts.length == 2 ? parts[1] : '').padRight(_decimals, '0');
  return int.parse(parts[0]) * _scale + int.parse(fraction);
}

/// The shortest exact text of [units] millionths (never below zero).
String counterQuantityText(int units) {
  final u = units < 0 ? 0 : units;
  final whole = u ~/ _scale;
  final fraction = (u % _scale).toString().padLeft(_decimals, '0').replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? '$whole' : '$whole.$fraction';
}

/// A line of a receipt as it was frozen.
class CounterBookLine {
  const CounterBookLine({
    required this.id,
    required this.lineNo,
    required this.label,
    required this.quantity,
    required this.unit,
    required this.grossMinor,
    required this.goods,
    this.correctsLineId,
  });

  final String id;
  final int lineNo;
  final String label;

  /// The exact quantity text the receipt froze.
  final String quantity;
  final String unit;
  final int grossMinor;

  /// A goods line: it left through the stock, and only goods lines are taken back.
  final bool goods;

  /// The original line a correction line credits.
  final String? correctsLineId;

  factory CounterBookLine.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_receipt_lines');
    final frozen = r.objectOrAbsent('frozen');
    final commercial = frozen.objectOrAbsent('commercial');
    return CounterBookLine(
      id: r.string('id'),
      lineNo: r.intOrNull('line_no') ?? 0,
      label: frozen.stringOr('label'),
      quantity: commercial.stringOr('quantity', '0'),
      unit: commercial.objectOrAbsent('unit').stringOr('code'),
      grossMinor: r.intOrNull('gross_minor') ?? 0,
      goods: frozen.stringOr('supply') == 'goods',
      correctsLineId: r.stringOrNull('corrects_line_id'),
    );
  }
}

/// What a tender was paid with; the wire word is read once, here. A word from the future is [unknown]: shown as it
/// came, never counted as cash or card.
enum TenderKind {
  cash('cash'),
  card('card'),
  other('other'),
  unknown('unknown');

  const TenderKind(this.wire);

  final String wire;

  static TenderKind of(String wire) => values.firstWhere((k) => k.wire == wire, orElse: () => unknown);
}

/// Where a tender stands; a word from the future is [unknown], the neutral state that is settled by hand.
enum TenderState {
  recorded('recorded'),
  requested('requested'),
  accepted('accepted'),
  refused('refused'),
  unknown('unknown');

  const TenderState(this.wire);

  final String wire;

  static TenderState of(String wire) => values.firstWhere((s) => s.wire == wire, orElse: () => unknown);
}

/// A tender of a receipt. A card tender moves `requested` -> `accepted` | `refused` | `unknown`; cash and other are
/// recorded `accepted` by the sale itself.
class CounterBookTender {
  const CounterBookTender({
    required this.id,
    required this.part,
    required this.kind,
    required this.amountMinor,
    required this.state,
    this.reconciliation,
    this.providerKey = '',
    this.providerRef = '',
  });

  final String id;
  final int part;

  /// `cash`, `card` or `other`.
  final String kind;
  final int amountMinor;

  /// `recorded`, `requested`, `unknown`, `accepted` or `refused`.
  final String state;

  /// `needed` (accepted for an offer that moved) or `done`; null otherwise.
  final String? reconciliation;

  /// The key the authorization was asked under: what the terminal's journal is searched for.
  final String providerKey;
  final String providerRef;

  /// The kind as an enum; a kind from the future reads as [TenderKind.unknown].
  TenderKind get tenderKind => TenderKind.of(kind);

  /// The state as an enum; a state from the future reads as [TenderState.unknown].
  TenderState get tenderState => TenderState.of(state);

  /// The answer has not been recorded, or was lost: it is settled, never asked again.
  bool get open => tenderKind == TenderKind.card && (tenderState == TenderState.requested || tenderState == TenderState.unknown);
  bool get needsReconciliation => state == 'accepted' && reconciliation == 'needed';

  /// Money taken that settles the sale.
  bool get settles => state == 'accepted' && reconciliation != 'needed';

  factory CounterBookTender.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_tenders');
    return CounterBookTender(
      id: r.string('id'),
      part: r.intOrNull('part') ?? 1,
      kind: r.string('kind'),
      amountMinor: r.intOrNull('amount_minor') ?? 0,
      state: r.string('state'),
      reconciliation: r.stringOrNull('reconciliation'),
      providerKey: r.stringOr('provider_key'),
      providerRef: r.stringOr('provider_ref'),
    );
  }
}

/// A receipt of the counter: a sale, a correction of a sale, or a draft whose card authorization is still open.
class CounterBookReceipt {
  const CounterBookReceipt({
    required this.id,
    required this.kind,
    required this.state,
    required this.currency,
    required this.totalMinor,
    required this.taxMinor,
    required this.revision,
    required this.lines,
    required this.tenders,
    this.number = '',
    this.finalizedAt,
    this.correctsId,
    this.reason = '',
    this.tillId,
    this.refundedMinor = 0,
    this.returned = const {},
  });

  final String id;

  /// `sale` or `correction`.
  final String kind;

  /// `draft` or `finalized`.
  final String state;
  final String currency;
  final int totalMinor;
  final int taxMinor;
  final int revision;
  final List<CounterBookLine> lines;
  final List<CounterBookTender> tenders;
  final String number;
  final DateTime? finalizedAt;

  /// The sale a correction credits.
  final String? correctsId;

  /// Why a correction was made, as it was frozen.
  final String reason;

  /// The till the sale was made at, where the till sessions run: a cash refund comes out of its drawer.
  final String? tillId;

  /// What was given back against this correction, in minor units.
  final int refundedMinor;

  /// Per goods line of this correction, the quantity already taken back (exact text).
  final Map<String, String> returned;

  bool get isSale => kind == 'sale';
  bool get isCorrection => kind == 'correction';
  bool get finalized => state == 'finalized';

  /// What is still to be refunded against this correction.
  int get refundLeftMinor => isCorrection ? (totalMinor - refundedMinor).clamp(0, totalMinor) : 0;

  /// What of goods line [line] of this correction is still to be taken back.
  String returnLeft(CounterBookLine line) =>
      counterQuantityText(counterQuantityUnits(line.quantity) - counterQuantityUnits(returned[line.id] ?? '0'));

  /// The card authorizations whose answer is not known.
  List<CounterBookTender> get openAuthorizations => [for (final t in tenders) if (t.open) t];

  /// The accepted card tenders that wait for a reconciliation.
  List<CounterBookTender> get toReconcile => [for (final t in tenders) if (t.needsReconciliation) t];

  /// A draft whose accepted card tenders settle it exactly and that nothing holds back: the sale can be completed.
  bool get completable =>
      !finalized &&
      openAuthorizations.isEmpty &&
      toReconcile.isEmpty &&
      tenders.any((t) => t.kind == 'card' && t.settles) &&
      tenders.where((t) => t.kind == 'card' && t.settles).fold<int>(0, (a, t) => a + t.amountMinor) == totalMinor;

  /// The accepted card tenders a completion names.
  List<String> get settlingCardTenders => [for (final t in tenders) if (t.kind == 'card' && t.settles) t.id];

  factory CounterBookReceipt.fromJson(
    Object? json, {
    required List<CounterBookLine> lines,
    required List<CounterBookTender> tenders,
    String? tillId,
    int refundedMinor = 0,
    Map<String, String> returned = const {},
  }) {
    final r = JsonReader.of(json, context: 'counter_receipts');
    final frozen = r.objectOrAbsent('frozen');
    final totals = frozen.objectOrAbsent('totals');
    return CounterBookReceipt(
      id: r.string('id'),
      kind: r.string('kind'),
      state: r.string('state'),
      currency: r.stringOr('currency'),
      totalMinor: r.intOrNull('total_minor') ?? int.tryParse(totals.stringOr('gross_minor')) ?? 0,
      taxMinor: r.intOrNull('tax_minor') ?? int.tryParse(totals.stringOr('tax_minor')) ?? 0,
      revision: r.intOrNull('revision') ?? 1,
      lines: lines,
      tenders: tenders,
      number: r.stringOr('number'),
      finalizedAt: r.dateTimeOrNull('finalized_at'),
      correctsId: r.stringOrNull('corrects_receipt_id'),
      reason: frozen.objectOrAbsent('corrects').stringOr('reason'),
      tillId: tillId,
      refundedMinor: refundedMinor,
      returned: returned,
    );
  }
}

/// The book as the screen reads it: the receipts, newest first, and what each sale has left to correct.
class CounterBook {
  const CounterBook(this.receipts);

  final List<CounterBookReceipt> receipts;

  /// The drafts whose card authorization waits for an answer, a reconciliation or the completion of the sale.
  List<CounterBookReceipt> get waiting => [
    for (final r in receipts)
      if (!r.finalized && r.tenders.any((t) => t.kind == 'card' && t.state != 'refused')) r,
  ];

  List<CounterBookReceipt> get issued => [for (final r in receipts) if (r.finalized) r];

  CounterBookReceipt? byId(String id) {
    for (final r in receipts) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// The corrections of sale [saleId].
  List<CounterBookReceipt> correctionsOf(String saleId) => [
    for (final r in receipts)
      if (r.isCorrection && r.correctsId == saleId) r,
  ];

  /// What of [line] of a sale is still to be corrected: its quantity less every correction of it.
  String leftOf(CounterBookLine line) {
    var units = counterQuantityUnits(line.quantity);
    for (final r in receipts) {
      if (!r.isCorrection || !r.finalized) continue;
      for (final l in r.lines) {
        if (l.correctsLineId == line.id) units -= counterQuantityUnits(l.quantity);
      }
    }
    return counterQuantityText(units);
  }
}

/// One line of a correction or a return: the line it names and the exact quantity.
class CounterBookQuantity {
  const CounterBookQuantity({required this.lineId, required this.quantity});

  final String lineId;
  final String quantity;

  Map<String, Object?> toJson() => {'corrects_line_id': lineId, 'quantity': quantity};
}

/// One part of a refund: `cash` (out of a drawer: the till where sessions run) or `other`.
class CounterRefundPart {
  const CounterRefundPart({required this.kind, required this.amountMinor, this.tillId});

  final String kind;
  final int amountMinor;
  final String? tillId;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'amount_minor': amountMinor,
    if (tillId != null) 'till_id': tillId,
  };
}

/// What a typed quantity of a correction or a return is, against what is [left].
enum CounterQuantityCheck { ok, empty, invalid, beyond }

/// [typed] as a correction or return quantity: nothing typed is not a line of it, a quantity must be exact and above
/// zero, and never above [left].
CounterQuantityCheck counterQuantityCheck(String typed, String left) {
  if (typed.trim().isEmpty) return CounterQuantityCheck.empty;
  final q = tillQuantityOf(typed);
  if (q == null) return CounterQuantityCheck.invalid;
  return counterQuantityUnits(q) > counterQuantityUnits(left) ? CounterQuantityCheck.beyond : CounterQuantityCheck.ok;
}

/// What a typed refund is, against what the correction has [leftMinor].
enum CounterRefundCheck { ok, invalid, beyond }

CounterRefundCheck counterRefundCheck(int? amountMinor, int leftMinor) {
  if (amountMinor == null || amountMinor <= 0) return CounterRefundCheck.invalid;
  return amountMinor > leftMinor ? CounterRefundCheck.beyond : CounterRefundCheck.ok;
}

/// The counter's book on the server. Every write goes under a request id: the same id again answers what it did.
abstract interface class CounterBookPort {
  Future<CounterBook> book(String workspaceId);

  /// A correction of sale [originalId]: a new receipt; answers its number.
  Future<String> correct(String workspaceId, {required String requestId, required String originalId, required List<CounterBookQuantity> lines, required String reason});

  /// Money given back against correction [correctionId].
  Future<void> refund(String workspaceId, {required String requestId, required String correctionId, required List<CounterRefundPart> parts});

  /// Goods of correction [correctionId] taken back into stock.
  Future<void> returnGoods(String workspaceId, {required String requestId, required String correctionId, required List<CounterBookQuantity> lines});

  /// The terminal's or the provider's answer to an open authorization: `accepted`, `refused` or `unknown`.
  Future<void> resolveTender(String workspaceId, {required String requestId, required String tenderId, required String outcome, required String providerRef});

  /// Money accepted for an offer that moved, reconciled explicitly.
  Future<void> reconcileTender(String workspaceId, {required String requestId, required String tenderId});

  /// The sale of draft [receiptId], settled by its accepted card tenders: answers its number.
  Future<String> complete(String workspaceId, {required String requestId, required String receiptId, required int expectedRevision, required List<String> tenderIds});
}

/// The receipt as text, to share: what the frozen document says, nothing recomputed.
String counterReceiptText(CounterBookReceipt r, {required String title, required String Function(int minor) money, required String total, required String tax}) {
  final out = StringBuffer()
    ..writeln(title)
    ..writeln(r.number);
  if (r.finalizedAt != null) out.writeln(r.finalizedAt!.toIso8601String());
  for (final l in r.lines) {
    out.writeln('${l.quantity} ${l.unit} ${l.label}  ${money(l.grossMinor)}'.replaceAll(RegExp(' +'), ' '));
  }
  out
    ..writeln('$total ${money(r.totalMinor)}')
    ..writeln('$tax ${money(r.taxMinor)}');
  return out.toString().trimRight();
}
