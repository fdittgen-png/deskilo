// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 (CS4) -- the till: the counter receipt as the screen needs it. The server (#4184/#4185) prices a basket
// (`counter_receipt_draft_v1`), numbers and takes tenders in ONE command (`counter_receipt_finalize_v1`) and says
// whether the country allows any of it (`counter_readiness_v1`); this file is what it answers and the port the till
// uses. Amounts are MINOR units; a quantity is an exact decimal string; nothing here prices a line.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

/// One operation of the counter in the business's country, under the case the owner declared.
class TillOperation {
  const TillOperation({required this.operation, required this.outcome, required this.reason, required this.note});

  /// `issue_receipt`, `correct_receipt`, `reconcile_tender`, `sign_fiscal`, `export_fiscal`.
  final String operation;

  /// `supported` or `unavailable`.
  final String outcome;

  /// Why it is unavailable: `unavailable` (the registry says so) or `adapter_missing`; empty when supported.
  final String reason;
  final String note;

  bool get supported => outcome == 'supported';

  factory TillOperation.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_readiness.operations');
    return TillOperation(operation: r.string('operation'), outcome: r.string('outcome'), reason: r.stringOr('reason'), note: r.stringOr('note'));
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
  const TillLine({required this.itemId, required this.name, required this.quantity, required this.unit});

  final String itemId;
  final String name;

  /// An exact decimal string (`^[0-9]{1,12}(\.[0-9]{1,6})?$`, above zero): a weighed quantity is a normal decimal.
  final String quantity;
  final String unit;

  TillLine withQuantity(String q) => TillLine(itemId: itemId, name: name, quantity: q, unit: unit);

  Map<String, Object?> toJson() => {'item_id': itemId, 'quantity': quantity};
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

/// A tender: `cash` or `other`, an exact amount in minor units.
class TillTender {
  const TillTender({required this.kind, required this.amountMinor});

  final String kind;
  final int amountMinor;

  Map<String, Object?> toJson() => {'kind': kind, 'amount_minor': amountMinor};
}

/// A sale made: its number and totals.
class TillSold {
  const TillSold({required this.receiptId, required this.number, required this.totals});

  final String receiptId;
  final String number;
  final TillTotals totals;

  factory TillSold.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_receipt_finalize');
    return TillSold(receiptId: r.string('receipt_id'), number: r.string('number'), totals: TillTotals.fromJson(r.raw('totals')));
  }
}

/// The till's server: readiness, a priced draft, and the one command that numbers a receipt and takes its tenders.
/// A refusal arrives as the server's own error (`knownRefusalText` says it in words).
abstract interface class TillPort {
  Future<TillReadiness> readiness(String workspaceId);

  /// Prices [lines]; [receiptId] and [expectedRevision] replace the lines of an open draft, both null make a new one.
  Future<TillDraft> draft(String workspaceId, {required String requestId, required List<TillLine> lines, String? receiptId, int? expectedRevision});

  Future<TillSold> finalize(String workspaceId, {required String requestId, required String receiptId, required int expectedRevision, required List<TillTender> tenders});
}
