// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';
import '../../../core/time/date_text.dart';
import 'purchase_obligation.dart';

export 'purchase_obligation.dart';

/// The permission that captures supplier bills; pinned to
/// `WorkspacePermission.managePurchases.wireName` by test, so the money
/// screen asks for it without importing the workspace permission catalogue.
const purchaseManagePermission = 'managePurchases';

/// Likewise for recording cash paid out (`recordOutgoingPayments`) and for
/// deciding a purchase (`approveExpenses`).
const purchasePayPermission = 'recordOutgoingPayments';
const purchaseDecidePermission = 'approveExpenses';
const purchaseOffsetPermission = 'issueInvoices';

/// What a purchase document is: a supplier bill, a credit note, or the
/// receipt of something a member paid (the expense flow's own document).
enum PurchaseKind {
  bill('bill'),
  creditNote('credit_note'),
  memberReceipt('member_receipt');

  const PurchaseKind(this.wire);

  final String wire;

  static PurchaseKind of(String? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => memberReceipt);
}

/// Where a document stands. Only the expense validation decides a member
/// receipt; a supplier bill stays a draft until its payable exists.
enum PurchaseState {
  draft,
  pending,
  approved,
  rejected,
  cancelled;

  static PurchaseState of(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => draft);
}

/// One line of a document. A null `taxCents` is "the document did not say",
/// never zero; a stated zero is a different, valid value.
class PurchaseLine {
  const PurchaseLine({
    required this.lineNo,
    required this.description,
    required this.grossCents,
    this.netCents,
    this.taxCents,
    this.taxRatePercent,
    this.recoverableTaxCents,
    this.recognitionKind = 'unresolved',
  });

  factory PurchaseLine.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'purchase line');
    return PurchaseLine(
      lineNo: r.integer('line_no'),
      description: r.stringOr('description'),
      grossCents: r.integer('gross_cents'),
      netCents: r.intOrNull('net_cents'),
      taxCents: r.intOrNull('tax_cents'),
      taxRatePercent: r.doubleOrNull('tax_rate_percent'),
      recoverableTaxCents: r.intOrNull('recoverable_tax_cents'),
      recognitionKind: r.stringOr('recognition_kind', 'unresolved'),
    );
  }

  final int lineNo;
  final String description;
  final int grossCents;
  final int? netCents;
  final int? taxCents;
  final double? taxRatePercent;
  final int? recoverableTaxCents;
  final String recognitionKind;

  bool get taxStated => taxCents != null;
}

/// The evidence behind a document: the expense event it came from, a
/// received supplier invoice.
class PurchaseSource {
  const PurchaseSource({
    required this.kind,
    required this.id,
    required this.role,
    this.reference = '',
  });

  factory PurchaseSource.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'purchase source');
    return PurchaseSource(
      kind: r.string('source_kind'),
      id: r.string('source_id'),
      role: r.stringOr('role'),
      reference: r.stringOr('original_reference'),
    );
  }

  final String kind;
  final String id;
  final String role;
  final String reference;
}

/// A document as the list shows it.
class PurchaseSummary {
  const PurchaseSummary({
    required this.id,
    required this.kind,
    required this.state,
    required this.category,
    required this.reference,
    required this.currency,
    this.grossCents = 0,
    this.receivedOn,
    this.originalDate,
    this.legacy = false,
  });

  /// A table row (lines embedded as `purchase_lines`) or a detail document
  /// (lines as `lines`).
  factory PurchaseSummary.fromRow(Object? raw) {
    final r = JsonReader.of(raw, context: 'purchase');
    var gross = 0;
    for (final key in const ['purchase_lines', 'lines']) {
      for (final l in r.listOrAbsent(key)) {
        gross += JsonReader.of(
          l,
          context: 'purchase line',
        ).integer('gross_cents');
      }
    }
    return PurchaseSummary(
      grossCents: gross,
      id: r.string('id'),
      kind: PurchaseKind.of(r.stringOrNull('kind')),
      state: PurchaseState.of(r.stringOrNull('state')),
      category: r.stringOr('category'),
      reference: r.stringOr('original_reference'),
      currency: r.stringOr('currency'),
      receivedOn: DateTime.tryParse(r.stringOr('received_on')),
      originalDate: DateTime.tryParse(r.stringOr('original_date')),
      legacy: r.stringOr('legacy_qualification', 'none') != 'none',
    );
  }

  final String id;
  final PurchaseKind kind;
  final PurchaseState state;
  final String category;
  final String reference;
  final String currency;

  /// The sum of the lines' gross amounts.
  final int grossCents;
  final DateTime? receivedOn;

  /// #2365 — the date the supplier put on the document: the day its entry
  /// is booked.
  final DateTime? originalDate;

  /// Filed before the purchase document existed: its supplier, date and
  /// classification are not verified.
  final bool legacy;
}

/// One document with its lines, evidence and supplier, as the server read it.
class PurchaseDetail {
  const PurchaseDetail({
    required this.summary,
    required this.revision,
    required this.lines,
    required this.sources,
    this.obligations = const [],
    this.supplierName,
    this.supplierNumber,
    this.dueOn,
  });

  factory PurchaseDetail.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'purchase detail');
    final supplier = r.objectOrNull('supplier');
    return PurchaseDetail(
      summary: PurchaseSummary.fromRow(raw),
      revision: r.integer('revision'),
      lines: [for (final l in r.list('lines')) PurchaseLine.fromJson(l)],
      sources: [for (final s in r.list('sources')) PurchaseSource.fromJson(s)],
      obligations: [
        for (final o in r.list('obligations')) PurchaseObligation.fromJson(o),
      ],
      supplierName: supplier?.stringOrNull('name'),
      supplierNumber: supplier?.stringOrNull('supplier_number'),
      dueOn: DateTime.tryParse(r.stringOr('due_on')),
    );
  }

  final PurchaseSummary summary;
  final int revision;
  final List<PurchaseLine> lines;
  final List<PurchaseSource> sources;

  /// What the space owes for this document; a member sees only their own.
  final List<PurchaseObligation> obligations;
  final String? supplierName;
  final String? supplierNumber;
  final DateTime? dueOn;

  int get grossCents => lines.fold(0, (sum, l) => sum + l.grossCents);

  /// Some line did not state its tax: the tax total is partial.
  bool get taxPartial => lines.any((l) => !l.taxStated);

  int get taxCents => lines.fold(0, (sum, l) => sum + (l.taxCents ?? 0));
}

/// What the bill dialog collects: ONE line, its tax optional. A bill with
/// several rates is captured by a later form, not guessed here.
class PurchaseBillDraft {
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
  });

  final String? purchaseId;
  final int expectedRevision;
  final String? supplierId;
  final String reference;
  final String description;
  final DateTime? originalDate;
  final DateTime? dueOn;
  final int grossCents;

  /// The tax the bill states; null when it does not (partial, not zero).
  final int? taxCents;

  /// #2576 — what the line is for, in the server's words: `operating`,
  /// `stock`, `asset`, `prepayment`, `deposit` or `unresolved` (needs
  /// review). Nobody has to choose a tax class or a useful life to submit.
  final String recognitionKind;

  static String? _day(DateTime? d) => d == null ? null : isoDay(d);

  /// The `save_purchase_draft_v1` payload. The server derives the actor, the
  /// state and the totals; none of them is sent.
  Map<String, Object?> toPayload() => {
    if (purchaseId != null) 'purchase_id': purchaseId,
    'kind': PurchaseKind.bill.wire,
    'supplier_id': supplierId,
    'original_reference': reference,
    'original_date': _day(originalDate),
    'due_on': _day(dueOn),
    'lines': [
      {
        'description': description,
        'gross_cents': grossCents,
        'recognition_kind': recognitionKind,
        if (taxCents != null) ...{
          'tax_cents': taxCents,
          'net_cents': grossCents - taxCents!,
        },
      },
    ],
  };
}

/// The purchase documents of a workspace and their commands.
abstract interface class PurchaseRepository {
  /// Newest first; the server shows a member their own and a manager all.
  Future<List<PurchaseSummary>> fetchPurchases(String workspaceId);

  Future<PurchaseDetail> fetchDetail(String workspaceId, String purchaseId);

  /// #2573 — the document a source was filed as (an expense request's
  /// event is filed as a member receipt), or null when there is none the
  /// reader may see.
  Future<String?> purchaseFiledFrom(
    String workspaceId, {
    required String sourceKind,
    required String sourceId,
  });

  /// What the space owes for approved purchases, newest first: a member sees
  /// their own claims, a manager all. [kind] narrows to members or suppliers.
  Future<List<PayableRow>> fetchPayables(
    String workspaceId, {
    CreditorKind? kind,
  });

  /// Records cash paid against a member's claim. The same request id with
  /// the same entries answers the original; returns the claim as it now
  /// stands.
  Future<PurchaseObligation> recordReimbursement(
    String workspaceId,
    ReimbursementCommand command,
  );

  /// Sends a captured supplier bill to approval. Returns the new state.
  Future<PurchaseState> submitBill(
    String workspaceId,
    String purchaseId,
    int revision,
    String requestId,
  );

  /// Approves or rejects a bill awaiting approval (another person than its
  /// submitter). A rejection carries its reason. Returns the new state.
  Future<PurchaseState> decideBill(
    String workspaceId,
    String purchaseId,
    int revision, {
    required bool approve,
    required String reason,
    required String requestId,
  });

  /// Applies a drafted credit note to the payable of the bill it reverses
  /// (another person than the one who captured it). Returns the new state.
  Future<PurchaseState> applyCreditNote(
    String workspaceId,
    String purchaseId,
    int revision,
    String requestId,
  );

  /// Settles (all or part of) one open invoice of the claimant from their
  /// claim. Returns the claim as it now stands.
  Future<PurchaseObligation> offsetClaim(String workspaceId, ClaimOffset offset);

  /// Reverses a recorded payment: the credit is whole again. Returns the
  /// claim as it now stands.
  Future<PurchaseObligation> reverseAllocation(
    String workspaceId, {
    required String allocationId,
    required int revision,
    required String reason,
    required String requestId,
  });

  /// Creates or updates a draft. The same [requestId] with the same draft
  /// returns the committed result, so a retry never doubles it. Returns the
  /// purchase id.
  Future<String> saveDraft(
    String workspaceId,
    String requestId,
    PurchaseBillDraft draft,
  );
}
