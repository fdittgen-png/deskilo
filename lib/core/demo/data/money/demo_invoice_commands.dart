// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice_commands.dart';
import 'package:deskilo/features/money/domain/invoicing_wizard.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/money_repository.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../money_repository.dart';
import 'demo_document_numbering.dart';
import 'demo_invoice_identity.dart';
import 'demo_invoice_tax.dart';
import 'demo_payment_apply.dart';

/// #2591 — what a person does to an invoice, in the demo: answered from one
/// space's in-memory money store ([FakeMoneyRepository]); every other port of
/// that space reads and writes the same store.
class DemoInvoiceCommands implements InvoiceCommands {
  DemoInvoiceCommands(this._m);

  final FakeMoneyRepository _m;

  /// The business's currency (the workspace's, on the server): what this
  /// space issues invoices in and the only one a payment settles (#3671).
  String currency = 'EUR';

  String _issuerOf(Invoice invoice) => _m.invoiceIdentity
      ?.call(invoice.workspaceId, invoice.memberId).issuerName ?? 'Flo';

  @override
  Future<String> createInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
    String? replacesId,
    bool detailed = false,
    InvoiceKind kind = InvoiceKind.full,
    String buyerReference = '',
    String purchaseOrder = '',
    String correctionReason = '',
  }) async {
    final identity = _m.invoiceIdentity?.call(workspaceId, memberId) ??
        demoDefaultInvoiceIdentity(memberId);
    _m.lastCorrectionReason = correctionReason;
    _m.lastBuyerReference = buyerReference;
    _m.lastPurchaseOrder = purchaseOrder;
    // Server contract (0067/0142): one ACTIVE invoice per member, month
    // and KIND — a full invoice blocks both kinds.
    _checkPeriod(memberId, period, kind, replacesId);
    // #827 — the kind narrows the lines the way invoice_lines_for does.
    final lines = [
      for (final l in _m.derivedLines(memberId, period))
        if (lineBelongsTo(l, kind)) l,
    ];
    if (lines.isEmpty) throw StateError('nothing to invoice for this period');
    var replacesNumber = '';
    if (replacesId != null) {
      // Server contract (0061): the reference must resolve, one direct
      // replacement per invoice, and the replaced one ends up voided in
      // the same transaction.
      final i = _m.invoices.indexWhere((inv) => inv.id == replacesId);
      if (i < 0) throw StateError('unknown invoice');
      if (_m.invoices.any((inv) => inv.replacesInvoiceId == replacesId)) {
        throw const PostgrestException(message: 'invoice already replaced', code: 'DKI05');
      }
      if (!_m.invoices[i].isVoided) {
        _m.invoices[i] = _m.invoices[i].copyWith(
          voidedAt: _m.clock(),
          voidedByName: identity.issuerName,
        );
      }
      replacesNumber = _m.invoices[i].number;
    }
    // #3292 — numbered by the space's invoice series and dated by its clock,
    // exactly as the numbering preview reads them.
    final series = demoSeriesOf(_m, 'invoice');
    final counter = series.nextValue;
    final invoice = Invoice(
      id: '${_m.invoiceIdentity == null ? '' : '$workspaceId-'}inv-${_m.nextInvoiceNumber}',
      workspaceId: workspaceId,
      memberId: memberId,
      number: series.format(counter, _m.clock()),
      issuedAt: _m.clock(),
      period: period,
      title: period,
      lines: lines,
      totalCents: lines.fold(0, (sum, l) => sum + l.amountCents),
      vatTotals: _m.invoiceIdentity == null ? const [] : demoInvoiceTaxTotals(lines),
      currency: currency,
      // Distinguishable snapshots for the archive filters.
      memberName: identity.memberName,
      memberAddress: identity.memberAddress,
      workspaceName: identity.workspaceName,
      workspaceAddress: identity.workspaceAddress,
      issuerName: identity.issuerName,
      sellerParty: identity.seller,
      buyerParty: identity.buyer?.copyWith(
          reference: buyerReference, orderReference: purchaseOrder),
      signature: 'f' * 64,
      replacesInvoiceId: replacesId,
      replacesNumber: replacesNumber,
      detailed: detailed,
      kind: kind,
      detailLedger: detailed ? _details(memberId, period) : const [],
      attendance: detailed ? List.of(_m.attendanceSeed) : const [],
    );
    // The counter moves past the number just issued (a series that already
    // numbered further sets it), so no number is ever issued twice.
    _m.nextInvoiceNumber =
        (counter > _m.nextInvoiceNumber ? counter : _m.nextInvoiceNumber) + 1;
    // A configured series counts on; the default one reads the counter.
    if (series.stored) {
      _m.numberSequences['invoice'] = series.copyWith(nextValue: counter + 1);
    }
    _m.invoices.insert(0, invoice);
    return invoice.id;
  }

  void _checkPeriod(String memberId, String period, InvoiceKind kind, String? replacesId) {
    if (_m.invoices.any((i) => i.memberId == memberId && i.period == period &&
        !i.isVoided && i.id != replacesId &&
        (i.kind == kind || i.kind == InvoiceKind.full || kind == InvoiceKind.full))) {
      throw const PostgrestException(message: 'period already invoiced for this member', code: 'DKI07');
    }
  }

  List<InvoiceDetailEntry> _details(String memberId, String period) => [
    for (final entry in _m.ledger)
      if (entry.memberId == memberId && entry.period == period)
        InvoiceDetailEntry(
          on: entry.createdAt.toIso8601String().split('T').first,
          category: entry.category.name, label: entry.description,
          amountCents: entry.kind == LedgerKind.credit ? -entry.amountCents : entry.amountCents),
  ];

  @override
  Future<String> issueInvoiceWithReceipt(InvoiceIssueCommand c) async {
    final receipts = _m.invoiceReceipts;
    final key = '${c.workspaceId}|${c.requestId}';
    final known = receipts[key];
    if (known != null) return known;
    final id = await createInvoice(
      workspaceId: c.workspaceId,
      memberId: c.memberId,
      period: c.period,
      detailed: c.detailed,
      kind: c.kind,
      buyerReference: c.buyerReference,
      purchaseOrder: c.purchaseOrder,
      correctionReason: c.correctionReason,
    );
    return receipts[key] = id;
  }

  @override
  Future<void> voidInvoice(String invoiceId) async {
    final i = _m.invoices.indexWhere((inv) => inv.id == invoiceId);
    if (i < 0) throw StateError('unknown invoice');
    // 0068 — a paid invoice is definitive.
    if (_m.invoiceMatchesStore.containsKey(invoiceId)) {
      throw const PostgrestException(message: 'invoice is matched', code: 'DKI04');
    }
    if (_m.invoices[i].isVoided) throw StateError('invoice already voided');
    _m.invoices[i] = _m.invoices[i].copyWith(
      voidedAt: _m.clock(),
      voidedByName: _issuerOf(_m.invoices[i]),
    );
  }

  @override
  Future<void> remindInvoice(String invoiceId) async {
    final invoice = _m.invoices.where((i) => i.id == invoiceId).firstOrNull;
    if (invoice == null) throw StateError('unknown invoice');
    if (invoice.isVoided) throw const PostgrestException(message: 'invoice is voided', code: 'DKI03');
    // #1913 — the server refuses a held invoice; so does the demo.
    if (_m.dunningHolds.containsKey(invoiceId)) {
      throw StateError('this invoice is on hold');
    }
    _m.invoiceReminders.putIfAbsent(invoiceId, () => []).add(_m.clock());
  }

  @override
  Future<void> settleCreditInvoice(String invoiceId, {String note = ''}) async {
    final invoice = _m.invoices.where((i) => i.id == invoiceId).firstOrNull;
    if (invoice == null) throw StateError('unknown invoice');
    if (invoice.totalCents >= 0) throw StateError('not a credit note');
    if (_m.invoiceMatchesStore.containsKey(invoiceId)) {
      throw const PostgrestException(message: 'invoice already matched', code: 'DKI06');
    }
    final trimmed = note.trim();
    _m.ledger.add(
      LedgerEntry(
        id: 'ledger-refund-${_m.ledger.length + 1}',
        memberId: invoice.memberId,
        kind: LedgerKind.charge,
        category: LedgerCategory.refund,
        amountCents: -invoice.totalCents,
        description:
            'Refund ${invoice.number}'
            '${trimmed.isEmpty ? '' : ' — $trimmed'}',
        period: yearMonth(_m.clock().year, _m.clock().month),
        createdAt: _m.clock(),
      ),
    );
    _m.invoiceMatchesStore[invoiceId] = InvoiceMatch(
      invoiceId: invoiceId,
      paidCents: -invoice.totalCents,
      resolution: 'refunded',
      note: trimmed,
      status: _m.matchPolicyConfigured ? 'pending' : 'confirmed',
      matchedAt: _m.clock(),
      byName: _issuerOf(invoice),
    );
  }

  @override
  Future<String> settleInvoices({
    required String workspaceId,
    required String memberId,
    required List<String> invoiceIds,
    String note = '',
  }) async {
    if (invoiceIds.length < 2) {
      throw StateError('settle at least two invoices');
    }
    _m.settlements.add((memberId: memberId, invoiceIds: invoiceIds));
    // #831 — build the document the server builds: the sources' lines
    // tagged with their number, the snapshot, the back-pointers.
    final sources = [
      for (final id in invoiceIds) ..._m.invoices.where((i) => i.id == id),
    ];
    // Older tests settle ids the fake never issued: they only observe
    // the call, so build nothing for them.
    if (sources.length != invoiceIds.length) return _m.nextSettlementId;
    final scope = _m.invoiceIdentity == null ? '' : '$workspaceId-';
    final settlementId = '${scope}inv-settle-${_m.settlements.length}';
    final settlement = Invoice(
      id: settlementId,
      workspaceId: workspaceId,
      memberId: memberId,
      number: _m.nextSettlementId,
      issuedAt: _m.clock(),
      title: _m.nextSettlementId,
      lines: [
        for (final s in sources)
          for (final l in s.lines) l.copyWith(sourceNumber: s.number),
      ],
      totalCents: sources.fold(0, (t, s) => t + s.totalCents),
      currency: sources.first.currency,
      memberName: sources.first.memberName,
      memberAddress: sources.first.memberAddress,
      workspaceName: sources.first.workspaceName,
      workspaceAddress: sources.first.workspaceAddress,
      issuerName: _issuerOf(sources.first),
      sellerParty: sources.first.sellerParty,
      buyerParty: sources.first.buyerParty,
      signature: 's' * 64,
      kind: InvoiceKind.settlement,
      settles: [
        for (final s in sources)
          SettledSource(
            invoiceId: s.id,
            number: s.number,
            period: s.period,
            kind: s.kind,
            totalCents: s.totalCents,
            lines: s.lines,
          ),
      ],
    );
    for (var i = 0; i < _m.invoices.length; i++) {
      if (invoiceIds.contains(_m.invoices[i].id)) {
        _m.invoices[i] = _m.invoices[i].copyWith(
          settledByInvoiceId: settlementId,
        );
      }
    }
    _m.invoices.insert(0, settlement);
    // The server returns the new document's id; the sheet looks its
    // number up from there (#831).
    return settlementId;
  }

  /// #3671 — the part [payment] settles on [invoiceId], as the server says
  /// it: a payment may settle several invoices and is taken again while
  /// something is left of it, never by the invoice that already holds a part;
  /// without an amount the part is what is left.
  int _partOf(
    LedgerEntry payment, {
    required String invoiceId,
    required String? latest,
    required int? amountCents,
  }) {
    final left = _m.remainingOf(payment);
    final holdsPart =
        latest == payment.id ||
        (_m.invoiceMatchPaymentsStore[invoiceId] ?? const []).any(
          (r) => r.paymentLedgerId == payment.id,
        );
    if (left <= 0 || holdsPart) throw StateError('payment already matched');
    if (amountCents != null && (amountCents <= 0 || amountCents > left)) {
      throw StateError('the amount is more than what is left of the payment');
    }
    return amountCents ?? left;
  }

  @override
  Future<void> matchInvoice({
    required String invoiceId,
    required String paymentLedgerId,
    required String resolution,
    String note = '',
    int? amountCents,
  }) async {
    final invoice = _m.invoices.where((i) => i.id == invoiceId).firstOrNull;
    if (invoice == null) throw StateError('unknown invoice');
    if (invoice.isVoided) throw const PostgrestException(message: 'invoice is voided', code: 'DKI03');
    // #506 — a STANDING partial accepts ADDITIONAL payments against the
    // remaining amount; anything else refuses like before.
    final existing = _m.invoiceMatchesStore[invoiceId];
    final additional =
        existing != null &&
        !existing.pending &&
        existing.resolution == 'under_accepted' &&
        existing.writeoffAt == null;
    if (existing != null && !additional) {
      throw const PostgrestException(message: 'invoice already matched', code: 'DKI06');
    }
    // 0068 — the amount comes FROM the selected registered payment;
    // #512 — account credits (credit-note excess) settle too.
    final payment = _m.ledger
        .where(
          (entry) =>
              entry.id == paymentLedgerId &&
              entry.memberId == invoice.memberId &&
              entry.kind == LedgerKind.credit &&
              (entry.category == LedgerCategory.payment ||
                  entry.category == LedgerCategory.adjustment),
        )
        .firstOrNull;
    if (payment == null) throw StateError('unknown payment');
    // #512 — a credit baked into an issued invoice was spent there.
    if (_m.invoices.any(
      (i) =>
          i.memberId == invoice.memberId &&
          !i.isVoided &&
          i.period == payment.period &&
          i.issuedAt.isAfter(payment.createdAt),
    )) {
      throw StateError('credit already deducted on an issued invoice');
    }
    final paidCents = _partOf(
      payment,
      invoiceId: invoiceId,
      latest: existing?.paymentLedgerId,
      amountCents: amountCents,
    );
    // #506 — every amount rule compares against what is STILL DUE.
    final dueCents = invoice.totalCents - (additional ? existing.paidCents : 0);
    final trimmed = note.trim();
    if (resolution == 'exact' && paidCents != dueCents) {
      throw StateError('amount does not match the invoice');
    }
    if ((resolution == 'over_forced' || resolution == 'over_credit_note') &&
        paidCents <= dueCents) {
      throw StateError('amount does not exceed the invoice');
    }
    if (resolution == 'under_accepted' && paidCents >= dueCents) {
      throw StateError('amount is not below the invoice');
    }
    if ((resolution == 'over_forced' || resolution == 'under_accepted') &&
        trimmed.isEmpty) {
      throw StateError('a note is required');
    }
    if (resolution == 'over_credit_note') {
      _m.ledger.add(
        LedgerEntry(
          id: 'ledger-credit-${_m.ledger.length + 1}',
          memberId: invoice.memberId,
          kind: LedgerKind.credit,
          category: LedgerCategory.adjustment,
          amountCents: paidCents - dueCents,
          description:
              'Credit note ${invoice.number}'
              '${trimmed.isEmpty ? '' : ' — $trimmed'}',
          period: yearMonth(_m.clock().year, _m.clock().month),
          createdAt: _m.clock(),
        ),
      );
    }
    _m.usePayment(paymentLedgerId, paidCents);
    if (additional) {
      // #506 — the aggregate grows; full settlement flips the state.
      _m.invoiceMatchesStore[invoiceId] = InvoiceMatch(
        invoiceId: invoiceId,
        paidCents: existing.paidCents + paidCents,
        resolution: resolution,
        note: trimmed.isEmpty ? existing.note : trimmed,
        paymentLedgerId: paymentLedgerId,
        matchedAt: _m.clock(),
        byName: _issuerOf(invoice),
      );
      return;
    }
    final eventId = _governedEvent(invoice, paidCents, resolution);
    _m.invoiceMatchesStore[invoiceId] = InvoiceMatch(
      invoiceId: invoiceId,
      paidCents: paidCents,
      resolution: resolution,
      note: trimmed,
      status: _m.matchPolicyConfigured ? 'pending' : 'confirmed',
      paymentLedgerId: paymentLedgerId,
      matchedAt: _m.clock(),
      byName: _issuerOf(invoice),
      eventId: eventId,
    );
  }

  /// #841 — a governed match carries the event that has to be validated,
  /// exactly as invoice_matches.event_id does on the server, so the document
  /// can show who released it. Null when no policy governs matches.
  String? _governedEvent(Invoice invoice, int paidCents, String resolution) {
    final eventRepository = _m.eventRepository;
    if (!_m.matchPolicyConfigured || eventRepository == null) return null;
    final eventId = 'invpay-${eventRepository.events.length + 1}';
    eventRepository.events.add(
      WorkspaceEvent(
        id: eventId,
        workspaceId: invoice.workspaceId,
        type: EventType.invoicePayment,
        action: EventAction.created,
        // #3293 — whoever recorded the match, not the first member.
        actorMemberId: eventRepository.respondingMemberId,
        subjectMemberId: invoice.memberId,
        payload: {
          'invoice_id': invoice.id,
          'paid_cents': paidCents,
          'resolution': resolution,
        },
        status: EventStatus.pending,
        createdAt: _m.clock(),
      ),
    );
    return eventId;
  }

  /// #3671 — one payment over several invoices (`demo_payment_apply.dart`).
  @override
  Future<PaymentApplied> applyPaymentToInvoices({
    required String workspaceId,
    required String paymentLedgerId,
    required List<PaymentAllocation> allocations,
    String note = '',
  }) => applyPaymentInDemo(
    _m,
    matchInvoice,
    paymentLedgerId: paymentLedgerId,
    allocations: allocations,
    note: note,
  );

  /// #3671 — what each open invoice of the payer can take now
  /// (`demo_payment_apply.dart`).
  @override
  Future<List<InvoiceCapacity>> paymentInvoiceCapacity({
    required String workspaceId,
    required String paymentLedgerId,
  }) async => paymentCapacityInDemo(_m, paymentLedgerId);
}
