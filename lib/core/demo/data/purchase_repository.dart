// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/purchase.dart';
import '../../../features/money/domain/vat_rate.dart';

/// Purchase documents in memory. The server derives the totals and files a
/// member's expense as a receipt through the same bridge; the demo only keeps
/// what the dialog saved, replaying a request id as the server does.
class FakePurchaseRepository implements PurchaseRepository {
  FakePurchaseRepository();

  /// The demo space: two approved claims of the demo members, one untouched
  /// and one part-paid, so the To-pay tab, a payment and a reversal can all
  /// be tried exactly as in production.
  factory FakePurchaseRepository.demo() => FakePurchaseRepository()
    ..payables.addAll([
      _demoClaim('demo-claim-1', 'member-2', 12000, 'cleaning supplies'),
      _demoClaim('demo-claim-3', 'member-1', 5400, 'event catering'),
      _demoClaim('demo-claim-4', 'member-2', 2850, 'reference books'),
      _demoClaim(
        'demo-claim-2',
        'member-3',
        8000,
        'coffee',
        paid: 3000,
        allocations: [
          SettlementAllocation(
            id: 'demo-allocation-0',
            isReversal: false,
            amountCents: 3000,
            method: 'bank_transfer',
            reference: 'Demo transfer',
            paidOn: DateTime(2026, 10, 10),
          ),
        ],
      ),
    ])
    ..claimRates.addAll({
      'p-demo-claim-1': 20,
      'p-demo-claim-2': 5.5,
      'p-demo-claim-3': 10,
      'p-demo-claim-4': 5.5,
    });

  /// The VAT rate of each claim's receipt (the demo states what the server
  /// would have read from the lines).
  final Map<String, double> claimRates = {};

  static PayableRow _demoClaim(
    String id,
    String member,
    int amount,
    String category, {
    int paid = 0,
    List<SettlementAllocation> allocations = const [],
  }) => PayableRow(
    obligation: PurchaseObligation(
      id: id,
      purchaseId: 'p-$id',
      creditorKind: CreditorKind.member,
      creditorId: member,
      amountCents: amount,
      currency: 'EUR',
      paidCents: paid,
      appliedCents: 0,
      remainingCents: amount - paid,
      allocations: allocations,
    ),
    purchase: PurchaseSummary(
      id: 'p-$id',
      kind: PurchaseKind.memberReceipt,
      state: PurchaseState.approved,
      category: category,
      reference: '',
      currency: 'EUR',
      grossCents: amount,
    ),
  );

  final List<PurchaseDetail> _documents = [];

  /// A document the demo space already holds (a bill captured, a receipt
  /// awaiting approval or refused).
  void add(PurchaseDetail document) => _documents.add(document);
  final Map<String, String> _requests = {};

  /// The claims the demo shows; the server derives them from approved
  /// receipts, the demo only keeps what a test or a scenario hands it.
  final List<PayableRow> payables = [];

  @override
  Future<List<PurchaseSummary>> fetchPurchases(String workspaceId) async => [
    for (final p in payables) p.purchase,
    for (final d in _documents.reversed) d.summary,
  ];

  @override
  Future<PurchaseDetail> fetchDetail(
    String workspaceId,
    String purchaseId,
  ) async {
    for (final d in _documents) {
      if (d.summary.id == purchaseId) return d;
    }
    // A claim's receipt, as the server reads it: one line, its claim.
    final row = payables.firstWhere(
      (r) => r.purchase.id == purchaseId,
      orElse: () => throw StateError('unknown purchase'),
    );
    return PurchaseDetail(
      summary: row.purchase,
      revision: 1,
      lines: [_receiptLine(row, claimRates[purchaseId])],
      sources: const [],
      obligations: [row.obligation],
    );
  }

  static PurchaseLine _receiptLine(PayableRow row, double? rate) {
    final gross = row.purchase.grossCents;
    if (rate == null) {
      return PurchaseLine(
        lineNo: 1,
        description: row.purchase.category,
        grossCents: gross,
      );
    }
    final split = vatSplit(gross, rate);
    return PurchaseLine(
      lineNo: 1,
      description: row.purchase.category,
      grossCents: gross,
      netCents: split.netCents,
      taxCents: split.vatCents,
      taxRatePercent: rate,
      recoverableTaxCents: split.vatCents,
    );
  }

  @override
  Future<List<PayableRow>> fetchPayables(
    String workspaceId, {
    CreditorKind? kind,
  }) async => [
    for (final p in payables)
      if (kind == null || p.obligation.creditorKind == kind) p,
  ];

  final Map<String, PurchaseObligation> _paid = {};

  int _row(String obligationId) =>
      payables.indexWhere((r) => r.obligation.id == obligationId);

  PurchaseObligation _restate(
    PurchaseObligation o, {
    required int paid,
    required List<SettlementAllocation> allocations,
  }) => PurchaseObligation(
    id: o.id,
    purchaseId: o.purchaseId,
    creditorKind: o.creditorKind,
    creditorId: o.creditorId,
    amountCents: o.amountCents,
    currency: o.currency,
    state: o.state,
    dueOn: o.dueOn,
    paidCents: paid,
    appliedCents: o.appliedCents,
    remainingCents: o.amountCents - paid - o.appliedCents,
    revision: o.revision + 1,
    mine: o.mine,
    allocations: allocations,
    appliedInvoice: o.appliedInvoice,
  );

  void _store(int i, PurchaseObligation o) => payables[i] = PayableRow(
    obligation: o,
    purchase: payables[i].purchase,
  );

  @override
  Future<PurchaseObligation> recordReimbursement(
    String workspaceId,
    ReimbursementCommand command,
  ) async {
    final replay = _paid[command.requestId];
    if (replay != null) return replay;
    final i = _row(command.obligationId);
    if (i < 0) throw StateError('unknown obligation');
    final o = payables[i].obligation;
    if (o.revision != command.revision) throw StateError('stale revision');
    if (!o.payable || command.amountCents <= 0 || command.amountCents > o.remainingCents) {
      throw StateError('the amount exceeds what remains of the claim');
    }
    final next = _restate(
      o,
      paid: o.paidCents + command.amountCents,
      allocations: [
        ...o.allocations,
        SettlementAllocation(
          id: 'demo-allocation-${o.allocations.length + 1}',
          isReversal: false,
          amountCents: command.amountCents,
          method: command.method.wire,
          reference: command.reference,
          paidOn: command.paidOn,
        ),
      ],
    );
    _store(i, next);
    return _paid[command.requestId] = next;
  }

  @override
  Future<PurchaseObligation> reverseAllocation(
    String workspaceId, {
    required String allocationId,
    required int revision,
    required String reason,
    required String requestId,
  }) async {
    final replay = _paid[requestId];
    if (replay != null) return replay;
    final i = payables.indexWhere(
      (r) => r.obligation.allocations.any((a) => a.id == allocationId),
    );
    if (i < 0) throw StateError('unknown allocation');
    final o = payables[i].obligation;
    final a = o.allocations.firstWhere((a) => a.id == allocationId);
    if (o.revision != revision) throw StateError('stale revision');
    if (!a.reversible || o.appliedInvoice != null) {
      throw StateError('this payment cannot be reversed');
    }
    final next = _restate(
      o,
      paid: o.paidCents - a.amountCents,
      allocations: [
        for (final x in o.allocations)
          if (x.id == a.id)
            SettlementAllocation(
              id: x.id,
              isReversal: false,
              amountCents: x.amountCents,
              method: x.method,
              reference: x.reference,
              paidOn: x.paidOn,
              reversed: true,
            )
          else
            x,
        SettlementAllocation(
          id: 'demo-reversal-${o.allocations.length + 1}',
          isReversal: true,
          amountCents: -a.amountCents,
          method: a.method,
          reference: reason,
        ),
      ],
    );
    _store(i, next);
    return _paid[requestId] = next;
  }

  @override
  Future<String> saveDraft(
    String workspaceId,
    String requestId,
    PurchaseBillDraft draft,
  ) async {
    final replay = _requests[requestId];
    if (replay != null) return replay;
    final id = draft.purchaseId ?? 'demo-purchase-${_documents.length + 1}';
    final tax = draft.taxCents;
    final detail = PurchaseDetail(
      summary: PurchaseSummary(
        id: id,
        kind: PurchaseKind.bill,
        state: PurchaseState.draft,
        category: '',
        reference: draft.reference,
        currency: '',
        receivedOn: draft.originalDate,
      ),
      revision: draft.expectedRevision + 1,
      lines: [
        PurchaseLine(
          lineNo: 1,
          description: draft.description,
          grossCents: draft.grossCents,
          netCents: tax == null ? null : draft.grossCents - tax,
          taxCents: tax,
        ),
      ],
      sources: const [],
      dueOn: draft.dueOn,
    );
    final i = _documents.indexWhere((d) => d.summary.id == id);
    if (i < 0) {
      _documents.add(detail);
    } else {
      _documents[i] = detail;
    }
    return _requests[requestId] = id;
  }
}
