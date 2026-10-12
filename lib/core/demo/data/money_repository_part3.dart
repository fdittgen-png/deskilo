// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'money_repository.dart';

// #2386 — part 3 of FakeMoneyRepository, split out of money_repository.dart so no
// file holds the whole class.
extension _FakeMoneyRepositoryPart3 on FakeMoneyRepository {

  Future<String> _requestUsageCorrectionImpl(
    String recordId, {
    String reason = '',
  }) async {
    final index = usageRecords.indexWhere((r) => r.id == recordId);
    if (index < 0) throw StateError('unknown usage record');
    final record = usageRecords[index];
    if (record.memberId != usageMemberId) {
      throw StateError('only the member concerned may ask for this');
    }
    if (record.isCorrected) throw StateError('already corrected');
    if (record.actualMinutes == null || record.checkedOutAt == null) {
      throw StateError('no check-out to correct to');
    }
    if (record.actualMinutes! >= record.reservedMinutes) {
      throw StateError('nothing to reduce');
    }
    // With a rule the correction waits for somebody else; without one it
    // stands at once, exactly as the RPC does.
    if (!usagePolicyConfigured) {
      usageRecords[index] = UsageRecord(
        id: record.id,
        memberId: record.memberId,
        reservationId: record.reservationId,
        period: record.period,
        reservedFrom: record.reservedFrom,
        reservedTo: record.reservedTo,
        checkedInAt: record.checkedInAt,
        checkedOutAt: record.checkedOutAt,
        countedMinutes: record.actualMinutes!,
        reservedMinutes: record.reservedMinutes,
        actualMinutes: record.actualMinutes,
        basis: UsageBasis.corrected,
        correctedFromMinutes: record.countedMinutes,
        correctedAt: kTestNow,
        spaceLabel: record.spaceLabel,
      );
    }
    return 'usage-event-${usageRecords.length}';
  }

  Future<String> _requestUsageRecordDeleteImpl(
    String recordId, {
    String reason = '',
  }) async {
    if (!usagePolicyConfigured) {
      usageRecords.removeWhere((r) => r.id == recordId);
    }
    return 'usage-delete-event';
  }

  Future<Map<String, InvoiceMatch>> _fetchInvoiceMatchesImpl(
    String workspaceId,
  ) async =>
      Map.of(invoiceMatchesStore);

  Future<Statement> _fetchStatementImpl(String memberId, String period) async {
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
      );
    }
    return statements[period] ?? statement.copyWith(period: period);
  }

  Future<MemberAccount> _fetchMemberAccountImpl(String memberId) async {
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
    final nowPeriod = yearMonth(kTestNow.year, kTestNow.month);
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

  Future<String> _distributeExpenseImpl({
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

  Future<List<ExpenseRepartition>> _fetchExpenseRepartitionsImpl(
          String workspaceId) async =>
      List.of(repartitions);

  Future<List<LedgerEntry>> _fetchWorkspaceLedgerImpl(String workspaceId) async =>
      List.of(ledger);

  Future<List<PaymentIntent>> _fetchPaymentIntentsImpl(String workspaceId) async =>
      List.of(paymentIntents);

  Future<List<LedgerEntry>> _fetchLedgerImpl(String memberId) async =>
      List.of(ledger);

  Future<String> _recordPaymentImpl({
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

  Future<EInvoiceGatewayConfig> _fetchEInvoiceGatewayImpl(
    String workspaceId,
  ) async =>
      einvoiceGateway;

  Future<EInvoiceSubmission> _sendEInvoiceImpl({
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

  Future<Map<String, InvoiceTransmission>> _fetchInvoiceTransmissionsImpl(
    String workspaceId,
  ) async =>
      Map.of(transmissions);

  Future<void> _setEInvoiceCredentialsImpl(
    String workspaceId,
    Map<String, String> config,
  ) async {
    // Mirrors the RPC: blank fields keep their stored value.
    config.forEach((key, value) {
      if (value.trim().isNotEmpty) einvoiceConfig[key] = value.trim();
    });
  }

  Future<void> _clearEInvoiceCredentialsImpl(String workspaceId) async =>
      einvoiceConfig.clear();

  Future<EInvoiceProviderStatus> _fetchEInvoiceStatusImpl(
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

  Future<List<FeeBand>> _fetchFeeBandsImpl(String workspaceId) async =>
      List.of(feeBands)..sort((a, b) => a.fromPct.compareTo(b.fromPct));

  Future<void> _replaceFeeBandsImpl(
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

  Future<SubscriptionLevels> _fetchSubscriptionLevelsImpl(
    String workspaceId,
  ) async =>
      subscriptionLevels;

  Future<void> _setSubscriptionLevelsImpl(
    String workspaceId,
    SubscriptionLevels levels,
  ) async {
    subscriptionLevels = levels;
  }

  Future<List<VatRate>> _fetchVatRatesImpl(String workspaceId) async =>
      vatRates.where((r) => r.active).toList()
        ..sort((a, b) => b.percent.compareTo(a.percent));

  Future<void> _setVatRatesImpl(String workspaceId, List<VatRate> rates) async {
    // Mirror set_vat_rates' precondition rather than accepting a set the
    // server would reject. An EMPTY set is allowed: that is how VAT is
    // turned back off.
    if (rates.isNotEmpty &&
        rates.where((r) => r.active && r.isDefault).length != 1) {
      throw StateError('exactly one default rate is required');
    }
    vatRates = [
      for (var i = 0; i < rates.length; i++)
        if (rates[i].id.isEmpty) VatRate(
                id: 'vat-${i + 1}',
                label: rates[i].label,
                percent: rates[i].percent,
                category: rates[i].category,
                isDefault: rates[i].isDefault,
                active: rates[i].active,
                groupKey: rates[i].groupKey,
                outsideBase: rates[i].outsideBase,
                exemptionReason: rates[i].exemptionReason,
                validFrom: rates[i].validFrom,
                validTo: rates[i].validTo,
                supersedesId: rates[i].supersedesId,
              ) else rates[i],
    ];
  }

  double _vatPercentOf(String vatRateId) => vatRateId.isEmpty
      ? _defaultVatPercent
      : vatRates
              .where((r) => r.id == vatRateId)
              .map((r) => r.percent)
              .firstOrNull ??
          _defaultVatPercent;

  Future<List<ServiceItem>> _fetchServicesImpl(
    String workspaceId, {
    bool includeInactive = false,
  }) async =>
      services.where((s) => includeInactive || s.active).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  Future<ServiceItem> _createServiceImpl(
    String workspaceId, {
    required String name,
    required int priceCents,
    String? vatRateId,
    SupplyClass supplyClass = SupplyClass.property,
  }) async {
    final service = ServiceItem(
      supplyClass: supplyClass,
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
}
