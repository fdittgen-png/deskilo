// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/domain/fee_band.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
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
  /// The immutable archive (0060); [createInvoice] mirrors the server's
  /// numbering + fingerprint contract.
  final invoices = <Invoice>[];
  var _nextInvoice = 1;

  @override
  Future<List<Invoice>> fetchInvoices(String workspaceId) async =>
      List.unmodifiable(invoices);

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
  }) async {
    // Server contract (0067): one ACTIVE invoice per member+month.
    if (invoices.any((i) =>
        i.memberId == memberId &&
        i.period == period &&
        !i.isVoided &&
        i.id != replacesId)) {
      throw StateError('period already invoiced for this member');
    }
    final lines = derivedLines(memberId, period);
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

  /// When true, matches land PENDING (a validation policy exists).
  bool matchPolicyConfigured = false;

  /// Seeds a CONFIRMED registered payment (0068) — what record_payment
  /// or an online settlement leaves on the ledger; returns its id.
  String seedPayment(String memberId, int amountCents,
      {String description = ''}) {
    final id = 'pay-${ledger.length + 1}';
    final now = kTestNow;
    ledger.add(LedgerEntry(
      id: id,
      memberId: memberId,
      kind: LedgerKind.credit,
      category: LedgerCategory.payment,
      amountCents: amountCents,
      description: description,
      period: '${now.year}-${now.month.toString().padLeft(2, '0')}',
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
    if (invoiceMatchesStore.containsKey(invoiceId)) {
      throw StateError('invoice already matched');
    }
    // 0068 — the amount comes FROM the selected registered payment.
    final payment = ledger
        .where((entry) =>
            entry.id == paymentLedgerId &&
            entry.memberId == invoice.memberId &&
            entry.kind == LedgerKind.credit &&
            entry.category == LedgerCategory.payment)
        .firstOrNull;
    if (payment == null) throw StateError('unknown payment');
    if (invoiceMatchesStore.values
        .any((m) => m.paymentLedgerId == paymentLedgerId)) {
      throw StateError('payment already matched');
    }
    final paidCents = payment.amountCents;
    final trimmed = note.trim();
    if (resolution == 'exact' && paidCents != invoice.totalCents) {
      throw StateError('amount does not match the invoice');
    }
    if ((resolution == 'over_forced' || resolution == 'over_credit_note') &&
        paidCents <= invoice.totalCents) {
      throw StateError('amount does not exceed the invoice');
    }
    if (resolution == 'under_accepted' &&
        paidCents >= invoice.totalCents) {
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
        amountCents: paidCents - invoice.totalCents,
        description: 'Credit note ${invoice.number}'
            '${trimmed.isEmpty ? '' : ' — $trimmed'}',
        period:
            '${kTestNow.year}-${kTestNow.month.toString().padLeft(2, '0')}',
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
    return statements[period] ?? statement.copyWith(period: period);
  }

  /// Online-payment attempts the fake reports for the export (#395).
  final paymentIntents = <PaymentIntent>[];

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
  final sentEInvoices =
      <({String invoiceId, String fileName, int bytes, String environment})>[];
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
  }) async {
    sentEInvoices.add((
      invoiceId: invoiceId,
      fileName: fileName,
      bytes: bytes.length,
      environment: environment,
    ));
    transmissions[invoiceId] = InvoiceTransmission(
      invoiceId: invoiceId,
      status: einvoiceOutcome,
      sentAt: kTestNow,
      externalId: 'platform-${sentEInvoices.length}',
      environment: environment,
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

  final submittedExpenses =
      <({int amountCents, String category, String description})>[];

  @override
  Future<String> submitExpense({
    required String workspaceId,
    required int amountCents,
    required String category,
    String description = '',
  }) async {
    submittedExpenses.add(
      (
        amountCents: amountCents,
        category: category,
        description: description,
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
