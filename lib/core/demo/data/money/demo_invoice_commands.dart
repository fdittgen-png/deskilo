// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/demo/data/fixture_clock.dart';
import 'package:deskilo/core/time/date_text.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_commands.dart';
import 'package:deskilo/features/money/domain/invoicing_wizard.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/money_repository.dart';

import '../money_repository.dart';

/// #2591 — what a person does to an invoice, in the demo: answered from one
/// space's in-memory money store ([FakeMoneyRepository]); every other port of
/// that space reads and writes the same store.
class DemoInvoiceCommands implements InvoiceCommands {
  DemoInvoiceCommands(this._m);

  final FakeMoneyRepository _m;

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
    _m.lastCorrectionReason = correctionReason;
    _m.lastBuyerReference = buyerReference;
    _m.lastPurchaseOrder = purchaseOrder;
    // Server contract (0067/0142): one ACTIVE invoice per member, month
    // and KIND — a full invoice blocks both kinds.
    if (_m.invoices.any(
      (i) =>
          i.memberId == memberId &&
          i.period == period &&
          !i.isVoided &&
          i.id != replacesId &&
          (i.kind == kind ||
              i.kind == InvoiceKind.full ||
              kind == InvoiceKind.full),
    )) {
      throw StateError('period already invoiced for this member');
    }
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
        throw StateError('invoice already replaced');
      }
      if (!_m.invoices[i].isVoided) {
        _m.invoices[i] = _m.invoices[i].copyWith(
          voidedAt: kTestNow,
          voidedByName: 'Flo',
        );
      }
      replacesNumber = _m.invoices[i].number;
    }
    final invoice = Invoice(
      id: 'inv-${_m.nextInvoiceNumber}',
      workspaceId: workspaceId,
      memberId: memberId,
      number: 'INV-2026-${_m.nextInvoiceNumber.toString().padLeft(4, '0')}',
      issuedAt: kTestNow,
      period: period,
      title: period,
      lines: lines,
      totalCents: lines.fold(0, (sum, l) => sum + l.amountCents),
      currency: 'EUR',
      // Distinguishable snapshots for the archive filters.
      memberName: memberId == 'member-1' ? 'Flo' : 'Ana',
      memberAddress: '1 Rue Test, 34120 Pézenas',
      workspaceName: 'Test Space',
      workspaceAddress: '2 Place du Marché, 34120 Pézenas',
      issuerName: 'Flo',
      signature: 'f' * 64,
      replacesInvoiceId: replacesId,
      replacesNumber: replacesNumber,
      detailed: detailed,
      kind: kind,
      detailLedger: detailed
          ? [
              for (final entry in _m.ledger)
                if (entry.memberId == memberId && entry.period == period)
                  InvoiceDetailEntry(
                    on: entry.createdAt.toIso8601String().split('T').first,
                    category: entry.category.name,
                    label: entry.description,
                    amountCents: entry.kind == LedgerKind.credit
                        ? -entry.amountCents
                        : entry.amountCents,
                  ),
            ]
          : const [],
      attendance: detailed ? List.of(_m.attendanceSeed) : const [],
    );
    _m.nextInvoiceNumber++;
    _m.invoices.insert(0, invoice);
    return invoice.id;
  }

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
      throw StateError('invoice is matched');
    }
    if (_m.invoices[i].isVoided) throw StateError('invoice already voided');
    _m.invoices[i] = _m.invoices[i].copyWith(
      voidedAt: kTestNow,
      voidedByName: 'Flo',
    );
  }

  @override
  Future<void> remindInvoice(String invoiceId) async {
    final invoice = _m.invoices.where((i) => i.id == invoiceId).firstOrNull;
    if (invoice == null) throw StateError('unknown invoice');
    if (invoice.isVoided) throw StateError('invoice is voided');
    // #1913 — the server refuses a held invoice; so does the demo.
    if (_m.dunningHolds.containsKey(invoiceId)) {
      throw StateError('this invoice is on hold');
    }
    _m.invoiceReminders.putIfAbsent(invoiceId, () => []).add(kTestNow);
  }

  @override
  Future<void> settleCreditInvoice(String invoiceId, {String note = ''}) async {
    final invoice = _m.invoices.where((i) => i.id == invoiceId).firstOrNull;
    if (invoice == null) throw StateError('unknown invoice');
    if (invoice.totalCents >= 0) throw StateError('not a credit note');
    if (_m.invoiceMatchesStore.containsKey(invoiceId)) {
      throw StateError('invoice already matched');
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
        period: yearMonth(kTestNow.year, kTestNow.month),
        createdAt: kTestNow,
      ),
    );
    _m.invoiceMatchesStore[invoiceId] = InvoiceMatch(
      invoiceId: invoiceId,
      paidCents: -invoice.totalCents,
      resolution: 'refunded',
      note: trimmed,
      status: _m.matchPolicyConfigured ? 'pending' : 'confirmed',
      matchedAt: kTestNow,
      byName: 'Flo',
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
    final settlementId = 'inv-settle-${_m.settlements.length}';
    final settlement = Invoice(
      id: settlementId,
      workspaceId: workspaceId,
      memberId: memberId,
      number: _m.nextSettlementId,
      issuedAt: kTestNow,
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
      issuerName: 'Flo',
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

  @override
  Future<void> matchInvoice({
    required String invoiceId,
    required String paymentLedgerId,
    required String resolution,
    String note = '',
  }) async {
    final invoice = _m.invoices.where((i) => i.id == invoiceId).firstOrNull;
    if (invoice == null) throw StateError('unknown invoice');
    if (invoice.isVoided) throw StateError('invoice is voided');
    // #506 — a STANDING partial accepts ADDITIONAL payments against the
    // remaining amount; anything else refuses like before.
    final existing = _m.invoiceMatchesStore[invoiceId];
    final additional =
        existing != null &&
        !existing.pending &&
        existing.resolution == 'under_accepted' &&
        existing.writeoffAt == null;
    if (existing != null && !additional) {
      throw StateError('invoice already matched');
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
    if (_m.invoiceMatchesStore.values.any(
      (m) => m.paymentLedgerId == paymentLedgerId,
    )) {
      throw StateError('payment already matched');
    }
    final paidCents = payment.amountCents;
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
          period: yearMonth(kTestNow.year, kTestNow.month),
          createdAt: kTestNow,
        ),
      );
    }
    _m.consumedPaymentIds.add(paymentLedgerId);
    if (additional) {
      // #506 — the aggregate grows; full settlement flips the state.
      _m.invoiceMatchesStore[invoiceId] = InvoiceMatch(
        invoiceId: invoiceId,
        paidCents: existing.paidCents + paidCents,
        resolution: resolution,
        note: trimmed.isEmpty ? existing.note : trimmed,
        paymentLedgerId: paymentLedgerId,
        matchedAt: kTestNow,
        byName: 'Flo',
      );
      return;
    }
    // #841 — a governed match carries the event that has to be
    // validated, exactly as invoice_matches.event_id does on the server,
    // so the document can show who released it.
    String? eventId;
    final eventRepository = _m.eventRepository;
    if (_m.matchPolicyConfigured && eventRepository != null) {
      eventId = 'invpay-${eventRepository.events.length + 1}';
      eventRepository.events.add(
        WorkspaceEvent(
          id: eventId,
          workspaceId: invoice.workspaceId,
          type: EventType.invoicePayment,
          action: EventAction.created,
          actorMemberId: 'member-1',
          subjectMemberId: invoice.memberId,
          payload: {
            'invoice_id': invoiceId,
            'paid_cents': paidCents,
            'resolution': resolution,
          },
          status: EventStatus.pending,
          createdAt: kTestNow,
        ),
      );
    }
    _m.invoiceMatchesStore[invoiceId] = InvoiceMatch(
      invoiceId: invoiceId,
      paidCents: paidCents,
      resolution: resolution,
      note: trimmed,
      status: _m.matchPolicyConfigured ? 'pending' : 'confirmed',
      paymentLedgerId: paymentLedgerId,
      matchedAt: kTestNow,
      byName: 'Flo',
      eventId: eventId,
    );
  }
}
