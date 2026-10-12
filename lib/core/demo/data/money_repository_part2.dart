// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'money_repository.dart';

// #2386 — part 2 of FakeMoneyRepository, split out of money_repository.dart so no
// file holds the whole class.
extension _FakeMoneyRepositoryPart2 on FakeMoneyRepository {

  Future<String> _createInvoiceImpl({
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
    lastCorrectionReason = correctionReason;
    lastBuyerReference = buyerReference;
    lastPurchaseOrder = purchaseOrder;
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

  Future<void> _voidInvoiceImpl(String invoiceId) async {
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

  Future<void> _remindInvoiceImpl(String invoiceId) async {
    final invoice = invoices.where((i) => i.id == invoiceId).firstOrNull;
    if (invoice == null) throw StateError('unknown invoice');
    if (invoice.isVoided) throw StateError('invoice is voided');
    // #1913 — the server refuses a held invoice; so does the demo.
    if (dunningHolds.containsKey(invoiceId)) {
      throw StateError('this invoice is on hold');
    }
    invoiceReminders.putIfAbsent(invoiceId, () => []).add(kTestNow);
  }

  /// #1922 — the demo sends by hand only, and its share sheet always
  /// completes: every reminder is the sender's declaration.
  Future<List<ReminderEvidence>> _fetchReminderEvidenceImpl(
    String invoiceId,
  ) async => [
    for (final (i, at) in (invoiceReminders[invoiceId] ?? const <DateTime>[]).indexed)
      ReminderEvidence(
        intentId: '$invoiceId-reminder-$i',
        level: i + 1,
        origin: 'manual',
        status: 'declared_delivered',
        preparedAt: at,
      ),
  ];

  Future<Map<String, String>> _fetchDunningHoldsImpl(String workspaceId) async =>
      Map.of(dunningHolds);

  Future<void> _placeDunningHoldImpl(
    String invoiceId, {
    required String reason,
    String note = '',
  }) async {
    if (dunningHolds.containsKey(invoiceId)) {
      throw StateError('this invoice is already on hold');
    }
    dunningHolds[invoiceId] = reason;
  }

  Future<void> _releaseDunningHoldImpl(String invoiceId) async {
    if (dunningHolds.remove(invoiceId) == null) {
      throw StateError('this invoice is not on hold');
    }
  }

  Future<void> _settleCreditInvoiceImpl(String invoiceId,
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
      period: yearMonth(kTestNow.year, kTestNow.month),
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

  Future<Map<String, List<TaxPointPayment>>> _fetchInvoiceInstalmentsImpl(
    String workspaceId,
  ) async =>
      {
        for (final entry in invoiceInstalmentsStore.entries)
          entry.key: List.of(entry.value),
      };

  Future<Set<String>> _fetchConsumedPaymentIdsImpl(String workspaceId) async =>
      {
        ...consumedPaymentIds,
        for (final match in invoiceMatchesStore.values)
          ?match.paymentLedgerId,
      };

  /// Seeds a CONFIRMED registered payment (0068) — what record_payment
  /// or an online settlement leaves on the ledger; returns its id.
  String _seedPaymentImpl(String memberId, int amountCents,
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
      period: period ?? yearMonth(now.year, now.month),
      createdAt: now,
    ));
    return id;
  }

  /// #512 — an account credit (credit-note excess, category
  /// 'adjustment') the imputation flow can spend on open invoices.
  String _seedCreditNoteImpl(String memberId, int amountCents,
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
      period: period ?? yearMonth(now.year, now.month),
      createdAt: now,
    ));
    return id;
  }

  Future<void> _matchInvoiceImpl({
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
            yearMonth(kTestNow.year, kTestNow.month),
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

  /// Seeds one record the way a check-out would leave it.
  UsageRecord _seedUsageImpl({
    required int reservedMinutes,
    int? actualMinutes,
    String memberId = 'member-1',
    String period = '2026-08',
    String space = 'Desk A1',
  }) {
    final from = DateTime.utc(2026, 8, 12, 9);
    final record = UsageRecord(
      id: 'usage-${_nextUsage++}',
      memberId: memberId,
      reservationId: 'res-$_nextUsage',
      period: period,
      reservedFrom: from,
      reservedTo: from.add(Duration(minutes: reservedMinutes)),
      checkedInAt: actualMinutes == null ? null : from,
      checkedOutAt: actualMinutes == null
          ? null
          : from.add(Duration(minutes: actualMinutes)),
      countedMinutes: reservedMinutes,
      reservedMinutes: reservedMinutes,
      actualMinutes: actualMinutes,
      spaceLabel: space,
    );
    usageRecords.add(record);
    return record;
  }

  Future<List<UsageRecord>> _fetchUsageRecordsImpl({
    required String workspaceId,
    required String period,
    String? memberId,
  }) async =>
      [
        for (final record in usageRecords)
          if (record.period == period &&
              (memberId == null || record.memberId == memberId))
            record,
      ];
}
