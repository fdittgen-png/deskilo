// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/expense_schedule.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/expense_repartition.dart';
import 'package:deskilo/features/money/domain/invoicing_wizard.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/price_negotiation.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/domain/fee_band.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/member_account.dart';
import 'package:deskilo/features/money/domain/money_repository.dart';
import 'package:deskilo/features/money/domain/package.dart';
import 'package:deskilo/features/money/domain/payment_intent.dart';
import 'package:deskilo/features/money/domain/payment_method.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/domain/statement.dart';

import 'test_clock.dart';
import 'package:deskilo/features/money/domain/subscription_levels.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';

import 'fake_event_repository.dart';

/// In-memory [MoneyRepository]; recorded payments are captured for
/// assertions (they only become ledger credits after confirmation).
class FakeMoneyRepository implements MoneyRepository {
  /// VAT declarations (0107), newest period first on read.
  final List<VatDeclaration> vatDeclarations = [];

  @override
  Future<List<VatDeclaration>> fetchVatDeclarations(
          String workspaceId) async =>
      List.of(vatDeclarations);

  @override
  Future<String> saveVatDeclaration({
    required String workspaceId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<VatDeclarationLine> lines,
    required int totalNetCents,
    required int totalVatCents,
    required String currency,
    required int invoiceCount,
  }) async {
    final existing = vatDeclarations.indexWhere((d) =>
        d.periodStart == periodStart && d.periodEnd == periodEnd);
    if (existing != -1 && vatDeclarations[existing].isSubmitted) {
      throw StateError('declaration already submitted for this period');
    }
    final declaration = VatDeclaration(
      id: existing != -1
          ? vatDeclarations[existing].id
          : 'decl-${vatDeclarations.length + 1}',
      workspaceId: workspaceId,
      periodStart: periodStart,
      periodEnd: periodEnd,
      status: 'draft',
      lines: lines,
      totalNetCents: totalNetCents,
      totalVatCents: totalVatCents,
      currency: currency,
      invoiceCount: invoiceCount,
      createdAt: DateTime.utc(2026, 8, 11),
    );
    if (existing != -1) {
      vatDeclarations[existing] = declaration;
    } else {
      vatDeclarations.add(declaration);
    }
    return declaration.id;
  }

  @override
  Future<void> markVatDeclarationSubmitted({
    required String declarationId,
    required String channel,
    String receipt = '',
  }) async {
    final index =
        vatDeclarations.indexWhere((d) => d.id == declarationId);
    if (index == -1) throw StateError('unknown declaration');
    final d = vatDeclarations[index];
    vatDeclarations[index] = VatDeclaration(
      id: d.id,
      workspaceId: d.workspaceId,
      periodStart: d.periodStart,
      periodEnd: d.periodEnd,
      status: 'submitted',
      lines: d.lines,
      totalNetCents: d.totalNetCents,
      totalVatCents: d.totalVatCents,
      currency: d.currency,
      invoiceCount: d.invoiceCount,
      createdAt: d.createdAt,
      submittedAt: DateTime.utc(2026, 8, 11, 12),
      submittedChannel: channel,
      submittedReceipt: receipt,
    );
  }

  /// Platform sends recorded for assertions; each accepted send stamps
  /// the declaration submitted like the edge function does.
  final List<String> sentDeclarationIds = [];

  @override
  Future<EInvoiceSubmission> sendVatDeclaration({
    required String workspaceId,
    required String declarationId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    sentDeclarationIds.add(declarationId);
    await markVatDeclarationSubmitted(
        declarationId: declarationId,
        channel: 'platform',
        receipt: 'fake-receipt');
    return const EInvoiceSubmission(
      status: EInvoiceSubmissionStatus.accepted,
      externalId: 'fake-receipt',
    );
  }

  /// #488 — the in-memory report-image library.
  final Map<String, List<int>> reportImages = {};

  @override
  Future<List<String>> listReportImages(String workspaceId) async =>
      reportImages.keys.toList()..sort();

  @override
  Future<void> uploadReportImage(
    String workspaceId, {
    required String name,
    required List<int> bytes,
    required String contentType,
  }) async {
    reportImages[name] = bytes;
  }

  @override
  Future<Uint8List?> fetchReportImage(
          String workspaceId, String name) async =>
      reportImages[name] == null
          ? null
          : Uint8List.fromList(reportImages[name]!);

  /// The immutable archive (0060); [createInvoice] mirrors the server's
  /// numbering + fingerprint contract.
  final invoices = <Invoice>[];
  var _nextInvoice = 1;

  @override
  Future<List<Invoice>> fetchInvoices(String workspaceId) async =>
      List.unmodifiable(invoices);

  /// #454 — per-workspace invoice-PDF template.
  InvoicePdfTemplate pdfTemplate = InvoicePdfTemplate.empty;

  @override
  Future<InvoicePdfTemplate> fetchInvoicePdfTemplate(
    String workspaceId,
  ) async =>
      pdfTemplate;

  @override
  Future<void> setInvoicePdfTemplate(
    String workspaceId,
    InvoicePdfTemplate template,
  ) async {
    pdfTemplate = template;
  }

  /// #472 — per-workspace dunning policy.
  DunningRules dunningRules = DunningRules.defaults;

  /// #739 — per member: the deal the fake serves; proposals recorded.
  final negotiations = <String, PriceNegotiation>{};
  final proposedNegotiations = <({String memberId, int? feeCents, int? overageFeeCents, double? discountPercent, String note, int? subscriptionPct, Map<String, Map<String, int>> items})>[];
  int negotiationReads = 0;

  @override
  Future<PriceNegotiation> fetchPriceNegotiation(String memberId) async {
    negotiationReads++;
    return negotiations[memberId] ??
        const PriceNegotiation(
          defaultFeeCents: 25000,
          defaultOverageFeeCents: 1200,
        );
  }

  @override
  Future<void> proposePriceNegotiation({
    required String memberId,
    int? feeCents,
    int? overageFeeCents,
    double? discountPercent,
    String note = '',
    DateTime? validFrom,
    int? subscriptionPct,
    Map<String, Map<String, int>> items = const {},
  }) async {
    proposedNegotiations.add((
      memberId: memberId,
      feeCents: feeCents,
      overageFeeCents: overageFeeCents,
      discountPercent: discountPercent,
      note: note,
      subscriptionPct: subscriptionPct,
      items: items,
    ));
    negotiations[memberId] = (negotiations[memberId] ??
            const PriceNegotiation(defaultFeeCents: 25000, defaultOverageFeeCents: 1200))
        .copyWith(
      pending: NegotiationDeal(
        feeCents: feeCents,
        overageFeeCents: overageFeeCents,
        discountPercent: discountPercent,
        note: note,
        validFrom: validFrom ?? kTestNow,
        status: 'pending',
        subscriptionPct: subscriptionPct,
        items: items,
      ),
    );
  }

  int sweeps = 0;

  @override
  Future<int> sweepPaymentReminders(String workspaceId) async {
    sweeps++;
    return 0;
  }

  @override
  Future<DunningRules> fetchDunningRules(String workspaceId) async =>
      dunningRules;

  @override
  Future<void> setDunningRules(
    String workspaceId,
    DunningRules rules,
  ) async {
    dunningRules = rules;
  }

  /// #804 — settlements requested, in order.
  final List<({String memberId, List<String> invoiceIds})> settlements = [];

  /// The id [settleInvoices] hands back.
  String nextSettlementId = 'INV-2026-9999';

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
    settlements.add((memberId: memberId, invoiceIds: invoiceIds));
    // #831 — build the document the server builds: the sources' lines
    // tagged with their number, the snapshot, the back-pointers.
    final sources = [
      for (final id in invoiceIds)
        ...invoices.where((i) => i.id == id),
    ];
    // Older tests settle ids the fake never issued: they only observe
    // the call, so build nothing for them.
    if (sources.length != invoiceIds.length) return nextSettlementId;
    final settlementId = 'inv-settle-${settlements.length}';
    final settlement = Invoice(
      id: settlementId,
      workspaceId: workspaceId,
      memberId: memberId,
      number: nextSettlementId,
      issuedAt: kTestNow,
      title: nextSettlementId,
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
    for (var i = 0; i < invoices.length; i++) {
      if (invoiceIds.contains(invoices[i].id)) {
        invoices[i] = invoices[i].copyWith(settledByInvoiceId: settlementId);
      }
    }
    invoices.insert(0, settlement);
    // The server returns the new document's id; the sheet looks its
    // number up from there (#831).
    return settlementId;
  }

  /// #802 — when the two automatic invoice runs happen.
  BillingRules billingRules = BillingRules.defaults;

  /// Workspaces passed to [sweepBillingInvoices], in order.
  final List<String> billingSweeps = [];

  @override
  Future<BillingRules> fetchBillingRules(String workspaceId) async =>
      billingRules;

  @override
  Future<void> setBillingRules(
    String workspaceId,
    BillingRules rules,
  ) async {
    billingRules = rules;
  }

  @override
  Future<int> sweepBillingInvoices(String workspaceId) async {
    billingSweeps.add(workspaceId);
    return 0;
  }

  /// Mirrors invoice_lines_for (0062): positions derive EXCLUSIVELY
  /// from the period's statement + confirmed ledger charges — nothing
  /// is accepted from the caller.
  List<InvoiceLine> derivedLines(String memberId, String period) {
    final s = statements[period] ?? statement.copyWith(period: period);
    return [
      if (s.feeCents > 0)
        InvoiceLine(
            kind: 'subscription',
            label: '${s.subscriptionPct}',
            amountCents: s.feeCents),
      if (s.overageCents > 0)
        InvoiceLine(
            kind: 'overage',
            label: '',
            quantity: s.extraHalfDays,
            amountCents: s.overageCents),
      if (s.accessorySupplementCents > 0)
        InvoiceLine(
            kind: 'accessories',
            label: '',
            amountCents: s.accessorySupplementCents),
      if (s.levelSupplementCents > 0)
        InvoiceLine(
            kind: 'level', label: '', amountCents: s.levelSupplementCents),
      if (s.officeSupplementCents > 0)
        InvoiceLine(
            kind: 'office', label: '', amountCents: s.officeSupplementCents),
      if (s.deskSupplementCents > 0)
        InvoiceLine(
            kind: 'desk', label: '', amountCents: s.deskSupplementCents),
      for (final entry in ledger)
        if (entry.memberId == memberId &&
            entry.period == period &&
            ((entry.kind == LedgerKind.charge &&
                    (entry.category == LedgerCategory.service ||
                        entry.category == LedgerCategory.package ||
                        entry.category == LedgerCategory.adjustment)) ||
                (entry.kind == LedgerKind.credit &&
                    (entry.category == LedgerCategory.payment ||
                        entry.category == LedgerCategory.expense ||
                        entry.category == LedgerCategory.adjustment))))
          InvoiceLine(
              kind: entry.category.name,
              label: entry.description,
              // 0063 — credits net against the charges: the total IS
              // the solde.
              amountCents: entry.kind == LedgerKind.credit
                  ? -entry.amountCents
                  : entry.amountCents),
    ];
  }

  @override
  Future<({List<InvoiceLine> lines, int totalCents})> previewInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
  }) async {
    final lines = derivedLines(memberId, period);
    return (
      lines: lines,
      totalCents: lines.fold(0, (sum, l) => sum + l.amountCents),
    );
  }

  /// Annex attendance rows the fake snapshots on detailed invoices —
  /// tests seed these (the money fake has no reservations access).
  List<InvoiceAttendance> attendanceSeed = [];

  @override
  Future<String> createInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
    String? replacesId,
    bool detailed = false,
    InvoiceKind kind = InvoiceKind.full,
  }) async {
    // Server contract (0067/0142): one ACTIVE invoice per member, month
    // and KIND — a full invoice blocks both kinds.
    if (invoices.any((i) =>
        i.memberId == memberId &&
        i.period == period &&
        !i.isVoided &&
        i.id != replacesId &&
        (i.kind == kind ||
            i.kind == InvoiceKind.full ||
            kind == InvoiceKind.full))) {
      throw StateError('period already invoiced for this member');
    }
    // #827 — the kind narrows the lines the way invoice_lines_for does.
    final lines = [
      for (final l in derivedLines(memberId, period))
        if (lineBelongsTo(l, kind)) l,
    ];
    if (lines.isEmpty) throw StateError('nothing to invoice for this period');
    var replacesNumber = '';
    if (replacesId != null) {
      // Server contract (0061): the reference must resolve, one direct
      // replacement per invoice, and the replaced one ends up voided in
      // the same transaction.
      final i = invoices.indexWhere((inv) => inv.id == replacesId);
      if (i < 0) throw StateError('unknown invoice');
      if (invoices.any((inv) => inv.replacesInvoiceId == replacesId)) {
        throw StateError('invoice already replaced');
      }
      if (!invoices[i].isVoided) {
        invoices[i] = invoices[i]
            .copyWith(voidedAt: kTestNow, voidedByName: 'Flo');
      }
      replacesNumber = invoices[i].number;
    }
    final invoice = Invoice(
      id: 'inv-$_nextInvoice',
      workspaceId: workspaceId,
      memberId: memberId,
      number: 'INV-2026-${_nextInvoice.toString().padLeft(4, '0')}',
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
              for (final entry in ledger)
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
      attendance: detailed ? List.of(attendanceSeed) : const [],
    );
    _nextInvoice++;
    invoices.insert(0, invoice);
    return invoice.id;
  }

  @override
  Future<void> voidInvoice(String invoiceId) async {
    final i = invoices.indexWhere((inv) => inv.id == invoiceId);
    if (i < 0) throw StateError('unknown invoice');
    // 0068 — a paid invoice is definitive.
    if (invoiceMatchesStore.containsKey(invoiceId)) {
      throw StateError('invoice is matched');
    }
    if (invoices[i].isVoided) throw StateError('invoice already voided');
    invoices[i] = invoices[i]
        .copyWith(voidedAt: kTestNow, voidedByName: 'Flo');
  }

  /// invoiceId → reminder instants (0066).
  final invoiceReminders = <String, List<DateTime>>{};

  @override
  Future<void> remindInvoice(String invoiceId) async {
    final invoice = invoices.where((i) => i.id == invoiceId).firstOrNull;
    if (invoice == null) throw StateError('unknown invoice');
    if (invoice.isVoided) throw StateError('invoice is voided');
    invoiceReminders.putIfAbsent(invoiceId, () => []).add(kTestNow);
  }

  @override
  Future<Map<String, ({int count, DateTime last})>> fetchInvoiceReminders(
    String workspaceId,
  ) async =>
      {
        for (final entry in invoiceReminders.entries)
          if (entry.value.isNotEmpty)
            entry.key: (
              count: entry.value.length,
              last: entry.value.last,
            ),
      };

  /// invoiceId → its match (0067). Mirrors the server contract:
  /// resolution/amount/note validation, pending while a validation
  /// policy is simulated, credit note as a ledger credit adjustment.
  final invoiceMatchesStore = <String, InvoiceMatch>{};

  /// #506 — every payment a match (or additional payment) consumed.
  final consumedPaymentIds = <String>{};

  @override
  Future<void> settleCreditInvoice(String invoiceId,
      {String note = ''}) async {
    final invoice = invoices.where((i) => i.id == invoiceId).firstOrNull;
    if (invoice == null) throw StateError('unknown invoice');
    if (invoice.totalCents >= 0) throw StateError('not a credit note');
    if (invoiceMatchesStore.containsKey(invoiceId)) {
      throw StateError('invoice already matched');
    }
    final trimmed = note.trim();
    ledger.add(LedgerEntry(
      id: 'ledger-refund-${ledger.length + 1}',
      memberId: invoice.memberId,
      kind: LedgerKind.charge,
      category: LedgerCategory.adjustment,
      amountCents: -invoice.totalCents,
      description: 'Refund ${invoice.number}'
          '${trimmed.isEmpty ? '' : ' — $trimmed'}',
      period:
          '${kTestNow.year}-${kTestNow.month.toString().padLeft(2, '0')}',
      createdAt: kTestNow,
    ));
    invoiceMatchesStore[invoiceId] = InvoiceMatch(
      invoiceId: invoiceId,
      paidCents: -invoice.totalCents,
      resolution: 'refunded',
      note: trimmed,
      status: matchPolicyConfigured ? 'pending' : 'confirmed',
      matchedAt: kTestNow,
      byName: 'Flo',
    );
  }

  @override
  Future<Set<String>> fetchConsumedPaymentIds(String workspaceId) async =>
      {
        ...consumedPaymentIds,
        for (final match in invoiceMatchesStore.values)
          ?match.paymentLedgerId,
      };

  /// When true, matches land PENDING (a validation policy exists).
  bool matchPolicyConfigured = false;

  /// Seeds a CONFIRMED registered payment (0068) — what record_payment
  /// or an online settlement leaves on the ledger; returns its id.
  String seedPayment(String memberId, int amountCents,
      {String description = '', String? period}) {
    final id = 'pay-${ledger.length + 1}';
    final now = kTestNow;
    ledger.add(LedgerEntry(
      id: id,
      memberId: memberId,
      kind: LedgerKind.credit,
      category: LedgerCategory.payment,
      amountCents: amountCents,
      description: description,
      period: period ??
          '${now.year}-${now.month.toString().padLeft(2, '0')}',
      createdAt: now,
    ));
    return id;
  }

  /// #512 — an account credit (credit-note excess, category
  /// 'adjustment') the imputation flow can spend on open invoices.
  String seedCreditNote(String memberId, int amountCents,
      {String description = 'Credit note', String? period}) {
    final id = 'avoir-${ledger.length + 1}';
    final now = kTestNow;
    ledger.add(LedgerEntry(
      id: id,
      memberId: memberId,
      kind: LedgerKind.credit,
      category: LedgerCategory.adjustment,
      amountCents: amountCents,
      description: description,
      period: period ??
          '${now.year}-${now.month.toString().padLeft(2, '0')}',
      createdAt: now,
    ));
    return id;
  }

  @override
  Future<void> matchInvoice({
    required String invoiceId,
    required String paymentLedgerId,
    required String resolution,
    String note = '',
  }) async {
    final invoice = invoices.where((i) => i.id == invoiceId).firstOrNull;
    if (invoice == null) throw StateError('unknown invoice');
    if (invoice.isVoided) throw StateError('invoice is voided');
    // #506 — a STANDING partial accepts ADDITIONAL payments against the
    // remaining amount; anything else refuses like before.
    final existing = invoiceMatchesStore[invoiceId];
    final additional = existing != null &&
        !existing.pending &&
        existing.resolution == 'under_accepted' &&
        existing.writeoffAt == null;
    if (existing != null && !additional) {
      throw StateError('invoice already matched');
    }
    // 0068 — the amount comes FROM the selected registered payment;
    // #512 — account credits (credit-note excess) settle too.
    final payment = ledger
        .where((entry) =>
            entry.id == paymentLedgerId &&
            entry.memberId == invoice.memberId &&
            entry.kind == LedgerKind.credit &&
            (entry.category == LedgerCategory.payment ||
                entry.category == LedgerCategory.adjustment))
        .firstOrNull;
    if (payment == null) throw StateError('unknown payment');
    // #512 — a credit baked into an issued invoice was spent there.
    if (invoices.any((i) =>
        i.memberId == invoice.memberId &&
        !i.isVoided &&
        i.period == payment.period &&
        i.issuedAt.isAfter(payment.createdAt))) {
      throw StateError('credit already deducted on an issued invoice');
    }
    if (invoiceMatchesStore.values
        .any((m) => m.paymentLedgerId == paymentLedgerId)) {
      throw StateError('payment already matched');
    }
    final paidCents = payment.amountCents;
    // #506 — every amount rule compares against what is STILL DUE.
    final dueCents =
        invoice.totalCents - (additional ? existing.paidCents : 0);
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
      ledger.add(LedgerEntry(
        id: 'ledger-credit-${ledger.length + 1}',
        memberId: invoice.memberId,
        kind: LedgerKind.credit,
        category: LedgerCategory.adjustment,
        amountCents: paidCents - dueCents,
        description: 'Credit note ${invoice.number}'
            '${trimmed.isEmpty ? '' : ' — $trimmed'}',
        period:
            '${kTestNow.year}-${kTestNow.month.toString().padLeft(2, '0')}',
        createdAt: kTestNow,
      ));
    }
    consumedPaymentIds.add(paymentLedgerId);
    if (additional) {
      // #506 — the aggregate grows; full settlement flips the state.
      invoiceMatchesStore[invoiceId] = InvoiceMatch(
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
    if (matchPolicyConfigured && _events != null) {
      eventId = 'invpay-${_events.events.length + 1}';
      _events.events.add(WorkspaceEvent(
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
      ));
    }
    invoiceMatchesStore[invoiceId] = InvoiceMatch(
      invoiceId: invoiceId,
      paidCents: paidCents,
      resolution: resolution,
      note: trimmed,
      status: matchPolicyConfigured ? 'pending' : 'confirmed',
      paymentLedgerId: paymentLedgerId,
      matchedAt: kTestNow,
      byName: 'Flo',
      eventId: eventId,
    );
  }

  @override
  Future<Map<String, InvoiceMatch>> fetchInvoiceMatches(
    String workspaceId,
  ) async =>
      Map.of(invoiceMatchesStore);

  FakeMoneyRepository({FakeEventRepository? events}) : _events = events;

  /// When wired, [recordServiceCharge] also files the pending
  /// service_charge event the real RPC creates (#134), so tests can drive
  /// the record → validate → bill flow through both fakes.
  final FakeEventRepository? _events;

  // Not const: the period follows the pinned test clock, so the screen
  // (which asks for the clock's month) and the fake agree. It used to be
  // the literal '2026-07', which made every bill test pass only during
  // July 2026.
  Statement statement = Statement(
    period: kTestPeriod,
    subscriptionPct: 50,
    feeCents: 15000,
    includedHalfDays: 22,
    openDays: 22,
    usedHalfDays: 24,
    extraHalfDays: 2,
    overageCents: 1600,
    creditsCents: 15000,
    balanceCents: -1600,
  );

  /// Per-period statements (#132); unseeded periods fall back to
  /// [statement] re-labelled with the requested period.
  final statements = <String, Statement>{};

  /// Every period the screen asked for, in order — lets tests assert the
  /// period chevrons change the query (#132).
  final fetchedPeriods = <String>[];

  final ledger = <LedgerEntry>[];
  final recordedPayments = <({
    int amountCents,
    String note,
    PaymentMethod? method,
    DateTime? paidOn,
    String? period,
  })>[];

  @override
  Future<Statement> fetchStatement(String memberId, String period) async {
    fetchedPeriods.add(period);
    // #512 — months fully before the membership owe NOTHING.
    if (memberJoinedPeriod != null && period.compareTo(memberJoinedPeriod!) < 0) {
      return Statement(
        period: period,
        subscriptionPct: statement.subscriptionPct,
        feeCents: 0,
        includedHalfDays: 0,
        openDays: 0,
        usedHalfDays: 0,
        extraHalfDays: 0,
        overageCents: 0,
        creditsCents: 0,
        balanceCents: 0,
        overagePolicy: statement.overagePolicy,
        overageRateCents: 0,
      );
    }
    return statements[period] ?? statement.copyWith(period: period);
  }

  /// #512 — when set, [fetchStatement] zeroes any earlier month, like
  /// member_statement does from the member's joined_at.
  String? memberJoinedPeriod;

  /// When set, [fetchMemberAccount] throws it — models a refused RPC
  /// (`not your account`) or a dead network, so a screen's error state
  /// can be exercised.
  Object? accountFailure;

  @override
  Future<MemberAccount> fetchMemberAccount(String memberId) async {
    if (accountFailure != null) throw accountFailure!;
    // Mirrors the member_account RPC over the fake stores.
    bool consumed(LedgerEntry e) => consumedPaymentIds.contains(e.id) ||
        invoiceMatchesStore.values.any((m) => m.paymentLedgerId == e.id);
    bool baked(LedgerEntry e) => invoices.any((i) =>
        i.memberId == memberId &&
        !i.isVoided &&
        i.period == e.period &&
        i.issuedAt.isAfter(e.createdAt));
    // Spare credit only: an avoir of any month, or a payment left over
    // from a PAST month — running-month payments offset the upcoming
    // invoice and stay ordinary payments.
    final nowPeriod =
        '${kTestNow.year}-${kTestNow.month.toString().padLeft(2, '0')}';
    final credit = ledger
        .where((e) =>
            e.memberId == memberId &&
            e.kind == LedgerKind.credit &&
            (e.category == LedgerCategory.adjustment ||
                (e.category == LedgerCategory.payment &&
                    e.period.compareTo(nowPeriod) < 0)) &&
            !consumed(e) &&
            !baked(e))
        .fold(0, (sum, e) => sum + e.amountCents);
    final replaced = {for (final i in invoices) ?i.replacesInvoiceId};
    final open = <OpenInvoicePosition>[];
    for (final invoice in invoices) {
      if (invoice.memberId != memberId ||
          invoice.isVoided ||
          invoice.totalCents <= 0 ||
          replaced.contains(invoice.id)) {
        continue;
      }
      final match = invoiceMatchesStore[invoice.id];
      final settledPartial = match != null &&
          !match.pending &&
          match.resolution == 'under_accepted' &&
          match.writeoffAt == null;
      if (match != null && !match.pending && !settledPartial) continue;
      final paid = settledPartial ? match.paidCents : 0;
      open.add((
        invoiceId: invoice.id,
        number: invoice.number,
        period: invoice.period ?? '',
        totalCents: invoice.totalCents,
        paidCents: paid,
        remainingCents: invoice.totalCents - paid,
      ));
    }
    final openTotal = open.fold(0, (sum, o) => sum + o.remainingCents);
    final refunds = invoices
        .where((i) =>
            i.memberId == memberId &&
            !i.isVoided &&
            i.totalCents < 0 &&
            invoiceMatchesStore[i.id] == null)
        .fold(0, (sum, i) => sum - i.totalCents);
    return MemberAccount(
      creditCents: credit,
      openInvoices: open,
      openTotalCents: openTotal,
      refundsDueCents: refunds,
      netPositionCents: credit + refunds - openTotal,
    );
  }

  /// Online-payment attempts the fake reports for the export (#395).
  final paymentIntents = <PaymentIntent>[];

  /// #828 — the distributions filed; [repartitionPolicyConfigured] makes
  /// them land pending (no ledger rows until a decision), else the
  /// shares book at once as adjustment rows the derived lines pick up.
  final repartitions = <ExpenseRepartition>[];
  bool repartitionPolicyConfigured = false;
  int _nextRepartition = 1;

  @override
  Future<String> distributeExpense({
    required String workspaceId,
    required String title,
    required int amountCents,
    required RepartitionMethod method,
    required String period,
    required List<RepartitionShare> shares,
    String? sourceEventId,
  }) async {
    if (amountCents == 0) throw StateError('amount must not be zero');
    if (shares.isEmpty) throw StateError('no shares');
    if (shares.fold(0, (s, x) => s + x.amountCents) != amountCents) {
      throw StateError('shares must add up to the amount');
    }
    final id = 'rep-${_nextRepartition++}';
    final pending = repartitionPolicyConfigured;
    if (!pending) {
      for (final share in shares) {
        ledger.add(LedgerEntry(
          id: 'ledger-rep-$id-${share.memberId}',
          memberId: share.memberId,
          kind: amountCents > 0 ? LedgerKind.charge : LedgerKind.credit,
          category: LedgerCategory.adjustment,
          amountCents: share.amountCents.abs(),
          description: title,
          period: period,
          createdAt: kTestNow,
        ));
      }
    }
    repartitions.insert(
      0,
      ExpenseRepartition(
        id: id,
        title: title,
        amountCents: amountCents,
        method: method,
        period: period,
        shares: shares,
        status: pending ? 'pending' : 'confirmed',
        createdAt: kTestNow,
        appliedAt: pending ? null : kTestNow,
      ),
    );
    return id;
  }

  @override
  Future<List<ExpenseRepartition>> fetchExpenseRepartitions(
          String workspaceId) async =>
      List.of(repartitions);

  @override
  Future<List<LedgerEntry>> fetchWorkspaceLedger(String workspaceId) async =>
      List.of(ledger);

  @override
  Future<List<PaymentIntent>> fetchPaymentIntents(String workspaceId) async =>
      List.of(paymentIntents);

  @override
  Future<List<LedgerEntry>> fetchLedger(String memberId) async =>
      List.of(ledger);

  @override
  Future<String> recordPayment({
    required String workspaceId,
    required String memberId,
    required int amountCents,
    String note = '',
    PaymentMethod? method,
    DateTime? paidOn,
    String? period,
  }) async {
    recordedPayments.add((
      amountCents: amountCents,
      note: note,
      method: method,
      paidOn: paidOn,
      period: period,
    ));
    return 'evt-payment-${recordedPayments.length}';
  }

  // ── e-invoice transmission (0071/0073) ──────────────────────────────

  /// What the fake platform answers. Unconfigured by default, so tests
  /// that do not care never see a Send button.
  EInvoiceGatewayConfig einvoiceGateway = EInvoiceGatewayConfig.notConfigured;

  /// The next submission's outcome, and what was actually posted.
  EInvoiceSubmissionStatus einvoiceOutcome =
      EInvoiceSubmissionStatus.accepted;
  final sentEInvoices = <({
    String invoiceId,
    String fileName,
    int bytes,
    String environment,
    String destination,
  })>[];
  final transmissions = <String, InvoiceTransmission>{};
  final einvoiceConfig = <String, String>{};

  @override
  Future<EInvoiceGatewayConfig> fetchEInvoiceGateway(
    String workspaceId,
  ) async =>
      einvoiceGateway;

  @override
  Future<EInvoiceSubmission> sendEInvoice({
    required String workspaceId,
    required String invoiceId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
    String environment = 'prod',
    String destination = 'government',
  }) async {
    sentEInvoices.add((
      invoiceId: invoiceId,
      fileName: fileName,
      bytes: bytes.length,
      environment: environment,
      destination: destination,
    ));
    transmissions[invoiceId] = InvoiceTransmission(
      invoiceId: invoiceId,
      status: einvoiceOutcome,
      sentAt: kTestNow,
      externalId: 'platform-${sentEInvoices.length}',
      environment: environment,
      destination: destination,
    );
    return EInvoiceSubmission(
      status: einvoiceOutcome,
      externalId: 'platform-${sentEInvoices.length}',
      detail: einvoiceOutcome == EInvoiceSubmissionStatus.accepted
          ? ''
          : 'the platform said no',
    );
  }

  @override
  Future<Map<String, InvoiceTransmission>> fetchInvoiceTransmissions(
    String workspaceId,
  ) async =>
      Map.of(transmissions);

  @override
  Future<void> setEInvoiceCredentials(
    String workspaceId,
    Map<String, String> config,
  ) async {
    // Mirrors the RPC: blank fields keep their stored value.
    config.forEach((key, value) {
      if (value.trim().isNotEmpty) einvoiceConfig[key] = value.trim();
    });
  }

  @override
  Future<void> clearEInvoiceCredentials(String workspaceId) async =>
      einvoiceConfig.clear();

  @override
  Future<EInvoiceProviderStatus> fetchEInvoiceStatus(
    String workspaceId,
  ) async =>
      EInvoiceProviderStatus(
        configured: einvoiceConfig.isNotEmpty,
        fields: {
          for (final entry in einvoiceConfig.entries)
            if (entry.key != 'auth_value') entry.key: entry.value,
        },
        secretsSet: [
          if (einvoiceConfig.containsKey('auth_value')) 'auth_value',
        ],
      );

  /// Mirrors the migration's default seed: (0,25] Flex-like, (25,50]
  /// Half-like, (50,100] Full-like (#128).
  final feeBands = <FeeBand>[
    const FeeBand(
      id: 'band-1',
      workspaceId: 'ws-1',
      fromPct: 0,
      toPct: 25,
      feeCents: 0,
      overageFeeCents: 1500,
    ),
    const FeeBand(
      id: 'band-2',
      workspaceId: 'ws-1',
      fromPct: 25,
      toPct: 50,
      feeCents: 15000,
      overageFeeCents: 800,
    ),
    const FeeBand(
      id: 'band-3',
      workspaceId: 'ws-1',
      fromPct: 50,
      toPct: 100,
      feeCents: 25000,
      overageFeeCents: 0,
    ),
  ];

  @override
  Future<List<FeeBand>> fetchFeeBands(String workspaceId) async =>
      List.of(feeBands)..sort((a, b) => a.fromPct.compareTo(b.fromPct));

  @override
  Future<void> replaceFeeBands(
    String workspaceId,
    List<FeeBand> bands,
  ) async {
    // Same contiguity contract as the replace_fee_bands RPC.
    var expected = 0;
    for (final band in bands.toList()
      ..sort((a, b) => a.fromPct.compareTo(b.fromPct))) {
      if (band.fromPct != expected) throw StateError('bands not contiguous');
      expected = band.toPct;
    }
    if (expected != 100) throw StateError('bands must cover up to 100');
    feeBands
      ..clear()
      ..addAll([
        for (final (i, band) in bands.indexed)
          band.copyWith(id: 'band-${i + 1}', workspaceId: workspaceId),
      ]);
  }

  SubscriptionLevels subscriptionLevels = const SubscriptionLevels();

  @override
  Future<SubscriptionLevels> fetchSubscriptionLevels(
    String workspaceId,
  ) async =>
      subscriptionLevels;

  @override
  Future<void> setSubscriptionLevels(
    String workspaceId,
    SubscriptionLevels levels,
  ) async {
    subscriptionLevels = levels;
  }

  final services = <ServiceItem>[
    const ServiceItem(
      id: 'service-coffee',
      workspaceId: 'ws-1',
      name: 'Coffee',
      priceCents: 150,
      active: true,
    ),
    const ServiceItem(
      id: 'service-locker',
      workspaceId: 'ws-1',
      name: 'Locker',
      priceCents: 500,
      active: false,
    ),
    const ServiceItem(
      id: 'service-printing',
      workspaceId: 'ws-1',
      name: 'Printing',
      priceCents: 20,
      active: true,
    ),
  ];

  /// The workspace's rates (0072); empty models a workspace that has not
  /// turned VAT on — which is every workspace before this migration.
  List<VatRate> vatRates = [];

  @override
  Future<List<VatRate>> fetchVatRates(String workspaceId) async =>
      vatRates.where((r) => r.active).toList()
        ..sort((a, b) => b.percent.compareTo(a.percent));

  @override
  Future<void> setVatRates(String workspaceId, List<VatRate> rates) async {
    // Mirror set_vat_rates' precondition rather than accepting a set the
    // server would reject. An EMPTY set is allowed: that is how VAT is
    // turned back off.
    if (rates.isNotEmpty &&
        rates.where((r) => r.active && r.isDefault).length != 1) {
      throw StateError('exactly one default rate is required');
    }
    vatRates = [
      for (var i = 0; i < rates.length; i++)
        rates[i].id.isEmpty
            ? VatRate(
                id: 'vat-${i + 1}',
                label: rates[i].label,
                percent: rates[i].percent,
                category: rates[i].category,
                isDefault: rates[i].isDefault,
                active: rates[i].active,
              )
            : rates[i],
    ];
  }

  /// What [recordServiceCharge] and [buyPackage] stamp when the item has no
  /// rate of its own — the fake's stand-in for
  /// `workspace_default_vat_percent`.
  double get _defaultVatPercent => vatRates
      .where((r) => r.active && r.isDefault)
      .map((r) => r.percent)
      .firstOrNull ??
      0;

  double _vatPercentOf(String vatRateId) => vatRateId.isEmpty
      ? _defaultVatPercent
      : vatRates
              .where((r) => r.id == vatRateId)
              .map((r) => r.percent)
              .firstOrNull ??
          _defaultVatPercent;

  @override
  Future<List<ServiceItem>> fetchServices(
    String workspaceId, {
    bool includeInactive = false,
  }) async =>
      services.where((s) => includeInactive || s.active).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<ServiceItem> createService(
    String workspaceId, {
    required String name,
    required int priceCents,
    String? vatRateId,
  }) async {
    final service = ServiceItem(
      id: 'service-${services.length + 1}',
      workspaceId: workspaceId,
      name: name,
      priceCents: priceCents,
      active: true,
      vatRateId: vatRateId ?? '',
    );
    services.add(service);
    return service;
  }

  @override
  Future<ServiceItem> updateService(
    String serviceId, {
    String? name,
    int? priceCents,
    bool? active,
    String? vatRateId,
  }) async {
    final i = services.indexWhere((s) => s.id == serviceId);
    if (i < 0) throw StateError('unknown service');
    final updated = services[i].copyWith(
      name: name ?? services[i].name,
      priceCents: priceCents ?? services[i].priceCents,
      active: active ?? services[i].active,
      vatRateId: vatRateId ?? services[i].vatRateId,
    );
    services[i] = updated;
    return updated;
  }

  /// Captured like [recordedPayments]: the real RPC only creates a pending
  /// event — nothing hits [ledger] until confirmation.
  final recordedServiceCharges = <({
    String workspaceId,
    String subjectMemberId,
    String serviceId,
    int quantity,
    String? period,
  })>[];

  @override
  Future<void> recordServiceCharge({
    required String workspaceId,
    required String subjectMemberId,
    required String serviceId,
    required int quantity,
    String? period,
  }) async {
    final service = services.firstWhere(
      (s) => s.id == serviceId,
      orElse: () => throw StateError('unknown service'),
    );
    if (!service.active) throw StateError('service is inactive');
    if (quantity < 1 || quantity > 999) {
      throw StateError('quantity must be between 1 and 999');
    }
    recordedServiceCharges.add(
      (
        workspaceId: workspaceId,
        subjectMemberId: subjectMemberId,
        serviceId: serviceId,
        quantity: quantity,
        period: period,
      ),
    );
    // Mirror the record_service_charge RPC: it only files a PENDING
    // service_charge event — the ledger charge appears on confirmation.
    final events = _events;
    if (events != null) {
      final now = kTestNow;
      events.events.add(
        WorkspaceEvent(
          id: 'evt-service-${recordedServiceCharges.length}',
          workspaceId: workspaceId,
          type: EventType.serviceCharge,
          action: EventAction.submitted,
          // The signed-in viewer records the charge, exactly like the RPC
          // stamps auth.uid()'s member as the actor.
          actorMemberId: events.respondingMemberId,
          subjectMemberId: subjectMemberId,
          payload: {
            'service_id': serviceId,
            'name': service.name,
            'price_cents': service.priceCents,
            'quantity': quantity,
            'amount_cents': service.priceCents * quantity,
            'vat_percent': _vatPercentOf(service.vatRateId),
            'period': period ??
                '${now.year}-${now.month.toString().padLeft(2, '0')}',
          },
          status: EventStatus.pending,
          createdAt: now,
        ),
      );
    }
  }

  final submittedExpenses = <({
    int amountCents,
    String category,
    String description,
    Map<String, Object?>? supply,
  })>[];

  /// #767 — seeded schedules/occurrences; the fake mirrors the server's
  /// two-lane rule: matching amount → added, deviation → needs a reason
  /// and goes pending; a rejected one resends the same way.
  final expenseSchedules = <ExpenseSchedule>[];
  final expenseOccurrences = <ExpenseOccurrence>[];
  final createdSchedules =
      <({String title, int amountCents, ScheduleUnit unit, int every,
         int? repeatCount, DateTime? endsOn})>[];
  final confirmedOccurrences =
      <({String occurrenceId, int amountCents, String reason})>[];
  int sweptSchedules = 0;

  @override
  Future<List<ExpenseSchedule>> fetchExpenseSchedules(String workspaceId) async =>
      List.of(expenseSchedules);

  @override
  Future<String> createExpenseSchedule({
    required String workspaceId,
    required String title,
    required int amountCents,
    required DateTime startsOn,
    required ScheduleUnit unit,
    int every = 1,
    int? repeatCount,
    DateTime? endsOn,
    String description = '',
  }) async {
    createdSchedules.add((title: title, amountCents: amountCents, unit: unit,
        every: every, repeatCount: repeatCount, endsOn: endsOn));
    final schedule = ExpenseSchedule(
      id: 'schedule-${expenseSchedules.length + 1}',
      workspaceId: workspaceId,
      memberId: 'member-1',
      title: title,
      description: description,
      amountCents: amountCents,
      startsOn: startsOn,
      endsOn: endsOn,
      unit: unit,
      every: every,
      repeatCount: repeatCount,
    );
    expenseSchedules.add(schedule);
    return schedule.id;
  }

  @override
  Future<void> cancelExpenseSchedule(String scheduleId) async {
    final i = expenseSchedules.indexWhere((s) => s.id == scheduleId);
    if (i < 0) return;
    final s = expenseSchedules[i];
    expenseSchedules[i] = ExpenseSchedule(
      id: s.id, workspaceId: s.workspaceId, memberId: s.memberId,
      title: s.title, description: s.description, amountCents: s.amountCents,
      startsOn: s.startsOn, endsOn: s.endsOn, unit: s.unit, every: s.every,
      repeatCount: s.repeatCount, status: ScheduleStatus.ended,
      occurrencesDone: s.occurrencesDone, nextDue: null,
    );
  }

  @override
  Future<int> sweepExpenseSchedules(String workspaceId) async {
    sweptSchedules++;
    return 0;
  }

  @override
  Future<List<ExpenseOccurrence>> fetchExpenseOccurrences(
          String workspaceId) async =>
      List.of(expenseOccurrences);

  @override
  Future<void> confirmExpenseOccurrence({
    required String occurrenceId,
    required int amountCents,
    String reason = '',
    String? note,
  }) async {
    final i = expenseOccurrences.indexWhere((o) => o.id == occurrenceId);
    if (i < 0) throw StateError('unknown occurrence');
    final o = expenseOccurrences[i];
    final matches = amountCents == (o.scheduledAmountCents ?? o.amountCents) &&
        o.status == OccurrenceStatus.awaitingMember;
    if (!matches && reason.trim().isEmpty) {
      throw StateError('a different amount needs an explanation');
    }
    confirmedOccurrences.add(
        (occurrenceId: occurrenceId, amountCents: amountCents, reason: reason));
    expenseOccurrences[i] = ExpenseOccurrence(
      id: o.id, scheduleId: o.scheduleId, workspaceId: o.workspaceId,
      memberId: o.memberId, dueOn: o.dueOn, amountCents: amountCents,
      note: note ?? o.note, deviationReason: reason,
      status: matches ? OccurrenceStatus.added : OccurrenceStatus.pendingValidation,
      scheduleTitle: o.scheduleTitle,
      scheduledAmountCents: o.scheduledAmountCents,
    );
  }

  @override
  Future<String> submitExpense({
    required String workspaceId,
    required int amountCents,
    required String category,
    String description = '',
    Map<String, Object?>? supply,
  }) async {
    submittedExpenses.add(
      (
        amountCents: amountCents,
        category: category,
        description: description,
        supply: supply,
      ),
    );
    return 'evt-expense-${submittedExpenses.length}';
  }

  /// Owner-defined packages; seeded with one 5-day pack by default.
  final packages = <Package>[
    const Package(
      id: 'package-5',
      workspaceId: 'ws-1',
      name: '5-day pack',
      days: 5,
      priceCents: 4000,
    ),
  ];

  @override
  Future<List<Package>> fetchPackages(
    String workspaceId, {
    bool includeInactive = false,
  }) async =>
      packages.where((p) => includeInactive || p.active).toList()
        ..sort((a, b) => a.days.compareTo(b.days));

  @override
  Future<Package> createPackage(
    String workspaceId, {
    required String name,
    required int days,
    required int priceCents,
    String? vatRateId,
  }) async {
    final package = Package(
      id: 'package-${packages.length + 1}',
      workspaceId: workspaceId,
      name: name,
      days: days,
      priceCents: priceCents,
      vatRateId: vatRateId ?? '',
    );
    packages.add(package);
    return package;
  }

  @override
  Future<Package> updatePackage(
    String packageId, {
    String? name,
    int? days,
    int? priceCents,
    bool? active,
    String? vatRateId,
  }) async {
    final i = packages.indexWhere((p) => p.id == packageId);
    if (i < 0) throw StateError('unknown package');
    final updated = packages[i].copyWith(
      name: name ?? packages[i].name,
      days: days ?? packages[i].days,
      priceCents: priceCents ?? packages[i].priceCents,
      active: active ?? packages[i].active,
      vatRateId: vatRateId ?? packages[i].vatRateId,
    );
    packages[i] = updated;
    return updated;
  }

  /// (workspaceId, packageId) of buy_package calls.
  final boughtPackages = <(String, String)>[];

  @override
  Future<String> buyPackage(String workspaceId, String packageId) async {
    boughtPackages.add((workspaceId, packageId));
    return 'ext-${boughtPackages.length}';
  }

  /// Providers the fake deployment offers; empty models "not configured".
  List<PaymentProvider> paymentProviders = [PaymentProvider.paypal];

  /// Per-provider missing env vars reported by the config probe.
  Map<String, List<String>> paymentMissing = const {};

  /// (provider, amountCents) of createPaymentOrder calls.
  final paymentOrders = <(PaymentProvider, int)>[];

  /// Approval URL the fake returns; null models an unconfigured provider.
  Uri? paymentApprovalUrl;

  @override
  Future<PaymentGatewayConfig> fetchPaymentConfig(String workspaceId) async =>
      PaymentGatewayConfig(
        providers: List.of(paymentProviders),
        missing: paymentMissing,
      );

  /// Per-provider server config the owner UI reads back.
  final Map<PaymentProvider, PaymentProviderStatus> paymentStatus = {};

  /// (provider, config) of setPaymentCredentials calls.
  final savedPaymentConfigs = <(PaymentProvider, Map<String, String>)>[];
  final clearedProviders = <PaymentProvider>[];

  @override
  Future<Map<PaymentProvider, PaymentProviderStatus>>
      fetchPaymentGatewayStatus(String workspaceId) async =>
          Map.of(paymentStatus);

  @override
  Future<void> setPaymentCredentials(
    String workspaceId,
    PaymentProvider provider,
    Map<String, String> config,
  ) async {
    savedPaymentConfigs.add((provider, config));
  }

  @override
  Future<void> clearPaymentProvider(
    String workspaceId,
    PaymentProvider provider,
  ) async {
    clearedProviders.add(provider);
  }

  @override
  Future<PaymentOrderStart> createPaymentOrder({
    required PaymentProvider provider,
    required String workspaceId,
    required String memberId,
    required int amountCents,
    required String currencyCode,
    required String period,
  }) async {
    paymentOrders.add((provider, amountCents));
    final url = paymentApprovalUrl;
    if (url == null) {
      return const PaymentOrderStart(missing: ['PAYPAL_CLIENT_ID']);
    }
    return PaymentOrderStart(approveUrl: url, orderId: 'order-1');
  }
}
