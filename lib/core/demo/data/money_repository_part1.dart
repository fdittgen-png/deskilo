// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'money_repository.dart';

// #2386 — part 1 of FakeMoneyRepository, split out of money_repository.dart so no
// file holds the whole class.
extension _FakeMoneyRepositoryPart1 on FakeMoneyRepository {

  Future<List<VatDeclaration>> _fetchVatDeclarationsImpl(
          String workspaceId) async =>
      List.of(vatDeclarations);

  /// The return of [start]..[end], filed periods locked (`vat_return_lines`).
  List<VatReturnAmount> _vatReturn(DateTime start, DateTime end) {
    final view = accountingView(invoices, invoiceMatchesStore);
    return vatReturnAmountsOf(vatTaxPointLedger(view.invoices,
            matches: view.matches,
            instalments: invoiceInstalmentsStore,
            basis: vatReturnBasis),
        start: start, end: end,
        locks: vatPeriodLocksOf(vatDeclarations), declared: vatDeclared);
  }

  /// Prepares the period like `save_vat_declaration` (0402/0406) with
  /// the Dart engine the SQL is the twin of.
  Future<String> _saveVatDeclarationImpl({
    required String workspaceId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final existing = vatDeclarations.indexWhere((d) =>
        d.periodStart == periodStart && d.periodEnd == periodEnd);
    if (existing != -1 && vatDeclarations[existing].isFiled) {
      throw StateError('declaration already filed for this period');
    }
    if (vatPeriodLocksOf(vatDeclarations).any((l) =>
        !l.start.isAfter(periodEnd) && !l.end.isBefore(periodStart))) {
      throw StateError('this period overlaps a filed return');
    }
    final amounts = _vatReturn(periodStart, periodEnd);
    final lines = vatReturnLinesOf(amounts, declarations: vatDeclarations);
    final documents = {for (final a in amounts) a.invoiceId};
    final declaration = VatDeclaration(
      id: existing != -1
          ? vatDeclarations[existing].id
          : 'decl-${vatDeclarations.length + 1}',
      workspaceId: workspaceId,
      periodStart: periodStart,
      periodEnd: periodEnd,
      status: 'prepared',
      lines: lines,
      totalNetCents: lines.fold(0, (sum, l) => sum + l.netCents),
      totalVatCents: lines.fold(0, (sum, l) => sum + l.vatCents),
      currency: 'EUR',
      invoiceCount: documents.length,
      createdAt: DateTime.utc(2026, 8, 11),
    );
    if (existing != -1) {
      vatDeclarations[existing] = declaration;
    } else {
      vatDeclarations.add(declaration);
    }
    return declaration.id;
  }

  Future<void> _markVatDeclarationSubmittedImpl({
    required String declarationId,
    required String channel,
    required String receipt,
  }) async {
    final index =
        vatDeclarations.indexWhere((d) => d.id == declarationId);
    if (index == -1) throw StateError('unknown declaration');
    final d = vatDeclarations[index];
    if (d.isFiled) throw StateError('declaration already filed');
    if (channel != 'manual' && channel != 'export') {
      throw StateError('unknown channel');
    }
    if (receipt.trim().isEmpty) {
      throw StateError('the receipt reference is required');
    }
    if (!d.isPrepared) throw StateError('prepare the return before filing it');
    vatDeclared.addAll(vatDeclaredBy(_vatReturn(d.periodStart, d.periodEnd)));
    vatDeclarations[index] = VatDeclaration(
      id: d.id,
      workspaceId: d.workspaceId,
      periodStart: d.periodStart,
      periodEnd: d.periodEnd,
      status: 'filed',
      lines: d.lines,
      totalNetCents: d.totalNetCents,
      totalVatCents: d.totalVatCents,
      currency: d.currency,
      invoiceCount: d.invoiceCount,
      createdAt: d.createdAt,
      submittedAt: DateTime.utc(2026, 8, 11, 12),
      submittedChannel: channel,
      submittedReceipt: receipt.trim(),
      number: 'DECL-2026-${(index + 1).toString().padLeft(4, '0')}',
    );
  }

  Future<List<String>> _listReportImagesImpl(String workspaceId) async =>
      reportImages.keys.toList()..sort();

  Future<void> _uploadReportImageImpl(
    String workspaceId, {
    required String name,
    required List<int> bytes,
    required String contentType,
  }) async {
    reportImages[name] = bytes;
  }

  Future<Uint8List?> _fetchReportImageImpl(
          String workspaceId, String name) async =>
      reportImages[name] == null
          ? null
          : Uint8List.fromList(reportImages[name]!);

  Future<List<Invoice>> _fetchInvoicesImpl(String workspaceId) async =>
      List.unmodifiable(invoices);

  Future<InvoicePdfTemplate> _fetchInvoicePdfTemplateImpl(
    String workspaceId,
  ) async =>
      pdfTemplate;

  Future<void> _setInvoicePdfTemplateImpl(
    String workspaceId,
    InvoicePdfTemplate template,
  ) async {
    pdfTemplate = template;
  }

  Future<PriceNegotiation> _fetchPriceNegotiationImpl(String memberId) async {
    negotiationReads++;
    return negotiations[memberId] ??
        const PriceNegotiation(
          defaultFeeCents: 25000,
          defaultOverageFeeCents: 1200,
        );
  }

  Future<void> _proposePriceNegotiationImpl({
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

  Future<int> _sweepPaymentRemindersImpl(String workspaceId) async {
    sweeps++;
    return 0;
  }

  Future<DunningRules> _fetchDunningRulesImpl(String workspaceId) async =>
      dunningRules;

  Future<void> _setDunningRulesImpl(
    String workspaceId,
    DunningRules rules,
  ) async {
    dunningRules = rules;
  }

  Future<String> _verifyInvoiceSignatureImpl(String invoiceId) async =>
      integrity[invoiceId] ?? 'verified';

  Future<List<NumberSequence>> _fetchNumberSequencesImpl(String workspaceId) async => [
    for (final j in NumberSequence.journals)
      numberSequences[j] ?? NumberSequence.defaultsFor(j),
  ];

  Future<void> _setNumberSequenceImpl(
    String workspaceId,
    NumberSequence sequence, {
    int? raiseNextValueTo,
  }) async {
    final current = numberSequences[sequence.journal];
    if (raiseNextValueTo != null &&
        current != null &&
        raiseNextValueTo < current.nextValue) {
      throw StateError('a sequence never goes backwards');
    }
    lastNumberSequence = sequence.copyWith(
      nextValue: raiseNextValueTo ?? current?.nextValue, stored: true,
    );
    numberSequences[sequence.journal] = lastNumberSequence!;
  }

  Future<String> _previewDocumentNumberImpl(
    String workspaceId,
    String journal,
  ) async {
    final s = numberSequences[journal] ?? NumberSequence.defaultsFor(journal);
    return s.format(s.nextValue, kTestNow);
  }

  Future<String> _settleInvoicesImpl({
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

  Future<BillingRules> _fetchBillingRulesImpl(String workspaceId) async =>
      billingRules;

  Future<void> _setBillingRulesImpl(
    String workspaceId,
    BillingRules rules,
  ) async {
    billingRules = rules;
  }

  Future<WorkspaceStatus> _fetchWorkspaceStatusImpl(
          String workspaceId, String from, String to) async =>
      status ?? demoWorkspaceStatus(this, from, to);

  Future<RepartitionRule> _fetchRepartitionRuleImpl(String workspaceId) async =>
      repartitionRule;

  Future<void> _setRepartitionRuleImpl(
      String workspaceId, RepartitionRule rule) async {
    repartitionRule = rule;
  }

  Future<int> _sweepBillingInvoicesImpl(String workspaceId) async {
    billingSweeps.add(workspaceId);
    return 0;
  }

  /// Mirrors invoice_lines_for (0062): positions derive EXCLUSIVELY
  /// from the period's statement + confirmed ledger charges — nothing
  /// is accepted from the caller.
  List<InvoiceLine> _derivedLinesImpl(String memberId, String period) {
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

  Future<List<String>> _invoiceIssueReadinessImpl({
    required String workspaceId,
    required String memberId,
    required String period,
    InvoiceKind kind = InvoiceKind.full,
    String? replacesId,
    String correctionReason = '',
  }) async => [
        for (final key in invoiceMissing)
          // #2440 — the server stops asking once a reason is given.
          if (key != 'correction_reason' || correctionReason.isEmpty) key,
      ];
}
