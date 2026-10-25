// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What a purchase draft sends to `save_purchase_draft_v1`: its lines, each
// with its tax as the document states it and the place its cost belongs to.
// The server derives the actor, the state and the totals; none is sent.
import '../../../core/time/date_text.dart';
import 'purchase.dart';
import 'vat_input.dart';

/// #2573 — a place a purchase line can name: a site of the space, or one of
/// its levels or offices (a resource names its site on the server).
class PurchasePlace {
  const PurchasePlace({
    required this.kind,
    required this.id,
    required this.name,
  });

  /// `site`, `level` or `office`.
  final String kind;
  final String id;
  final String name;

  bool get isSite => kind == 'site';

  /// The keys the line sends for this place.
  Map<String, Object?> toJson() => isSite
      ? {'cost_site_id': id}
      : {'resource_kind': kind, 'resource_id': id};

  @override
  bool operator ==(Object other) =>
      other is PurchasePlace && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// One line of a draft. A null [taxCents] is "the document did not say",
/// never zero.
class PurchaseLineDraft {
  const PurchaseLineDraft({
    required this.grossCents,
    this.description = '',
    this.taxCents,
    this.taxRatePercent,
    this.recoverableTaxCents,
    this.recognitionKind = 'unresolved',
    this.place,
  });

  /// A line of [grossCents] taxed at [percent], of which [deductiblePct]
  /// percent of the tax may be deducted, split as the server rounds it
  /// (`vat_split_net`, `vat_input_split`). A [percent] of 0 states a line
  /// without tax (zero-rated or exempt), which is not an unknown tax.
  factory PurchaseLineDraft.atRate({
    required int grossCents,
    required double percent,
    required double deductiblePct,
    String description = '',
    String recognitionKind = 'unresolved',
    PurchasePlace? place,
  }) {
    if (percent <= 0) {
      return PurchaseLineDraft(
        grossCents: grossCents,
        description: description,
        taxCents: 0,
        taxRatePercent: 0,
        recoverableTaxCents: 0,
        recognitionKind: recognitionKind,
        place: place,
      );
    }
    final split = vatInputSplit(grossCents, percent, deductiblePct);
    return PurchaseLineDraft(
      grossCents: grossCents,
      description: description,
      taxCents: grossCents - split.netCents,
      taxRatePercent: percent,
      recoverableTaxCents: split.deductibleCents,
      recognitionKind: recognitionKind,
      place: place,
    );
  }

  final int grossCents;
  final String description;
  final int? taxCents;
  final double? taxRatePercent;

  /// The tax the space may deduct; null while nobody has qualified it.
  final int? recoverableTaxCents;

  /// What the line is for, in the server's words: `operating`, `stock`,
  /// `asset`, `prepayment`, `deposit` or `unresolved` (needs review).
  final String recognitionKind;
  final PurchasePlace? place;

  Map<String, Object?> toJson() => {
    'description': description,
    'gross_cents': grossCents,
    'recognition_kind': recognitionKind,
    if (taxCents != null) ...{
      'tax_cents': taxCents,
      'net_cents': grossCents - taxCents!,
    },
    'tax_rate_percent': ?taxRatePercent,
    'recoverable_tax_cents': ?recoverableTaxCents,
    ...?place?.toJson(),
  };

  /// The line as the server stores it at [lineNo] (the demonstration).
  PurchaseLine toLine(int lineNo) => PurchaseLine(
    lineNo: lineNo,
    description: description,
    grossCents: grossCents,
    netCents: taxCents == null ? null : grossCents - taxCents!,
    taxCents: taxCents,
    taxRatePercent: taxRatePercent,
    recoverableTaxCents: recoverableTaxCents,
    recognitionKind: recognitionKind,
    costSiteId: place?.isSite == true ? place!.id : null,
    resourceKind: place?.isSite == false ? place!.kind : null,
    resourceId: place?.isSite == false ? place!.id : null,
    placeName: place?.name ?? '',
  );
}

/// A draft `save_purchase_draft_v1` takes.
abstract interface class PurchaseDraft {
  /// Null for a new document.
  String? get purchaseId;
  int get expectedRevision;
  PurchaseKind get kind;
  String get category;
  String get reference;
  DateTime? get originalDate;
  DateTime? get dueOn;
  List<PurchaseLineDraft> get lines;

  /// The RPC's payload.
  Map<String, Object?> toPayload();
}

String? _day(DateTime? d) => d == null ? null : isoDay(d);

/// What the bill dialog collects: ONE line, its tax optional.
class PurchaseBillDraft implements PurchaseDraft {
  const PurchaseBillDraft({
    required this.grossCents,
    this.purchaseId,
    this.expectedRevision = 0,
    this.supplierId,
    this.reference = '',
    this.description = '',
    this.originalDate,
    this.dueOn,
    this.taxCents,
    this.recognitionKind = 'unresolved',
    this.place,
  });

  @override
  final String? purchaseId;
  @override
  final int expectedRevision;
  final String? supplierId;
  @override
  final String reference;
  final String description;
  @override
  final DateTime? originalDate;
  @override
  final DateTime? dueOn;
  final int grossCents;

  /// The tax the bill states; null when it does not (partial, not zero).
  final int? taxCents;

  /// #2576 — what the line is for, in the server's words: `operating`,
  /// `stock`, `asset`, `prepayment`, `deposit` or `unresolved` (needs
  /// review). Nobody has to choose a tax class or a useful life to submit.
  final String recognitionKind;

  /// #2573 — where its cost belongs; null names no place.
  final PurchasePlace? place;

  @override
  PurchaseKind get kind => PurchaseKind.bill;

  @override
  String get category => '';

  @override
  List<PurchaseLineDraft> get lines => [
    PurchaseLineDraft(
      grossCents: grossCents,
      description: description,
      taxCents: taxCents,
      recognitionKind: recognitionKind,
      place: place,
    ),
  ];

  @override
  Map<String, Object?> toPayload() => {
    if (purchaseId != null) 'purchase_id': purchaseId,
    'kind': PurchaseKind.bill.wire,
    'supplier_id': supplierId,
    'original_reference': reference,
    'original_date': _day(originalDate),
    'due_on': _day(dueOn),
    'lines': [for (final l in lines) l.toJson()],
  };
}

/// #2573 — a member's receipt of several lines: each line its own rate,
/// deductible share, class and place. Submitted, it files ONE expense of the
/// whole amount through the existing validation.
class PurchaseReceiptDraft implements PurchaseDraft {
  const PurchaseReceiptDraft({
    required this.category,
    required this.lines,
    this.purchaseId,
    this.expectedRevision = 0,
    this.reference = '',
    this.originalDate,
  });

  @override
  final String? purchaseId;
  @override
  final int expectedRevision;
  @override
  final String category;
  @override
  final List<PurchaseLineDraft> lines;
  @override
  final String reference;
  @override
  final DateTime? originalDate;

  @override
  DateTime? get dueOn => null;

  @override
  PurchaseKind get kind => PurchaseKind.memberReceipt;

  int get grossCents => lines.fold(0, (sum, l) => sum + l.grossCents);

  /// The same entries under the next revision of [purchaseId].
  PurchaseReceiptDraft savedAs(String purchaseId, int expectedRevision) =>
      PurchaseReceiptDraft(
        category: category,
        lines: lines,
        purchaseId: purchaseId,
        expectedRevision: expectedRevision,
        reference: reference,
        originalDate: originalDate,
      );

  @override
  Map<String, Object?> toPayload() => {
    if (purchaseId != null) 'purchase_id': purchaseId,
    'kind': PurchaseKind.memberReceipt.wire,
    'category': category,
    'original_reference': reference,
    'original_date': _day(originalDate),
    'lines': [for (final l in lines) l.toJson()],
  };
}

/// Why a receipt cannot be sent yet.
enum ReceiptProblem { amount, deductible }

/// The first problem of a receipt whose lines were typed as [grosses]
/// (null: not a number) and [shares] (null: not a number), with the index
/// of its line; null when it can be sent. The server checks again.
({ReceiptProblem problem, int line})? receiptProblem({
  required List<int?> grosses,
  required List<double?> shares,
}) {
  for (var i = 0; i < grosses.length; i++) {
    final g = grosses[i];
    if (g == null || g <= 0) return (problem: ReceiptProblem.amount, line: i);
  }
  for (var i = 0; i < shares.length; i++) {
    final s = shares[i];
    if (s == null || s < 0 || s > 100) {
      return (problem: ReceiptProblem.deductible, line: i);
    }
  }
  return null;
}
