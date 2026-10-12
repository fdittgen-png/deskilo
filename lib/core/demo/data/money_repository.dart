// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:deskilo/core/vat/supply_class.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/accounting_view.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/domain/expense_repartition.dart';
import 'package:deskilo/features/money/domain/expense_schedule.dart';
import 'package:deskilo/features/money/domain/fee_band.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/invoicing_wizard.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/member_account.dart';
import 'package:deskilo/features/money/domain/money_repository.dart';
import 'package:deskilo/features/money/domain/number_sequence.dart';
import 'package:deskilo/features/money/domain/package.dart';
import 'package:deskilo/features/money/domain/payment_intent.dart';
import 'package:deskilo/features/money/domain/payment_method.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/money/domain/price_negotiation.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/money/domain/subscription_levels.dart';
import 'package:deskilo/features/money/domain/usage_record.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/vat_period_lock.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';
import 'package:deskilo/features/money/domain/workspace_status.dart';

import '../../../features/money/domain/reminder_evidence.dart';
import '../../time/date_text.dart';
import 'event_repository.dart';
import 'fixture_clock.dart';
import 'workspace_status_computation.dart';

part 'money_repository_part1.dart';
part 'money_repository_part2.dart';
part 'money_repository_part3.dart';
part 'money_repository_part4.dart';

/// In-memory [MoneyRepository]; recorded payments are captured for
/// assertions (they only become ledger credits after confirmation).
class FakeMoneyRepository implements MoneyRepository {
  /// VAT declarations (0107), newest period first on read.
  final List<VatDeclaration> vatDeclarations = [];

  /// #2357 — the basis the fake prepares on (the server reads the space's).
  VatTaxPointBasis vatReturnBasis = VatTaxPointBasis.invoiceDate;

  /// #2357 (0406) — what each filed return declared (`vat_return_entries`).
  final List<VatDeclaredAmount> vatDeclared = [];

  /// #488 — the in-memory report-image library.
  final Map<String, List<int>> reportImages = {};

  /// The immutable archive (0060); [createInvoice] mirrors the server's
  /// numbering + fingerprint contract.
  final invoices = <Invoice>[];
  var _nextInvoice = 1;

  /// #454 — per-workspace invoice-PDF template.
  InvoicePdfTemplate pdfTemplate = InvoicePdfTemplate.empty;

  /// #472 — per-workspace dunning policy.
  DunningRules dunningRules = DunningRules.defaults;

  /// #739 — per member: the deal the fake serves; proposals recorded.
  final negotiations = <String, PriceNegotiation>{};
  final proposedNegotiations = <({String memberId, int? feeCents, int? overageFeeCents, double? discountPercent, String note, int? subscriptionPct, Map<String, Map<String, int>> items})>[];
  int negotiationReads = 0;

  int sweeps = 0;

  /// #925 — the series as the fake holds them.
  final numberSequences = <String, NumberSequence>{
    'invoice': const NumberSequence(journal: 'invoice', prefix: 'INV-'),
  };
  NumberSequence? lastNumberSequence;

  /// #956 — what the fake answers for an invoice's fingerprint.
  final integrity = <String, String>{};

  /// #804 — settlements requested, in order.
  final List<({String memberId, List<String> invoiceIds})> settlements = [];

  /// The id [settleInvoices] hands back.
  String nextSettlementId = 'INV-2026-9999';

  /// #922 — what the last issue carried, for assertions.
  String lastBuyerReference = '';
  String lastPurchaseOrder = '';

  /// #802 — when the two automatic invoice runs happen.
  BillingRules billingRules = BillingRules.defaults;

  /// Workspaces passed to [sweepBillingInvoices], in order.
  final List<String> billingSweeps = [];

  /// #934 — the status the fake answers with (#2327: else computed).
  WorkspaceStatus? status;
  RepartitionRule repartitionRule = const RepartitionRule();

  /// Tests seed what the server would report missing.
  List<String> invoiceMissing = const [];

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

  /// invoiceId → reminder instants (0066).
  final invoiceReminders = <String, List<DateTime>>{};

  /// #1913 — invoiceId → reason of its active hold.
  final Map<String, String> dunningHolds = {};

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

  /// #2355 — the instalments recorded one by one; tests seed them here.
  final invoiceInstalmentsStore = <String, List<TaxPointPayment>>{};

  /// When true, matches land PENDING (a validation policy exists).
  bool matchPolicyConfigured = false;

  /// #833 — the month's usage records, keyed by reservation like the
  /// server's table. The fake mirrors the server's rules: a correction
  /// may only be asked for by the member concerned, only once, and only
  /// when there is something to reduce.
  final usageRecords = <UsageRecord>[];
  bool usagePolicyConfigured = false;
  String usageMemberId = 'member-1';
  var _nextUsage = 1;

  FakeMoneyRepository({this._events});

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

  /// #512 — when set, [fetchStatement] zeroes any earlier month, like
  /// member_statement does from the member's joined_at.
  String? memberJoinedPeriod;

  /// When set, [fetchMemberAccount] throws it — models a refused RPC
  /// (`not your account`) or a dead network, so a screen's error state
  /// can be exercised.
  Exception? accountFailure;

  /// Online-payment attempts the fake reports for the export (#395).
  final paymentIntents = <PaymentIntent>[];

  /// #828 — the distributions filed; [repartitionPolicyConfigured] makes
  /// them land pending (no ledger rows until a decision), else the
  /// shares book at once as adjustment rows the derived lines pick up.
  final repartitions = <ExpenseRepartition>[];
  bool repartitionPolicyConfigured = false;
  int _nextRepartition = 1;

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

  SubscriptionLevels subscriptionLevels = const SubscriptionLevels();

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

  /// Captured like [recordedPayments]: the real RPC only creates a pending
  /// event — nothing hits [ledger] until confirmation.
  final recordedServiceCharges = <({
    String workspaceId,
    String subjectMemberId,
    String serviceId,
    int quantity,
    String? period,
  })>[];

  final submittedExpenses = <({
    int amountCents,
    String category,
    String description,
    Map<String, Object?>? supply,
  })>[];

  /// #2357 — the VAT each submitted expense carried, in order.
  final submittedExpenseVat = <Map<String, Object?>?>[];

  /// #2357 — the VAT each schedule's occurrences carry.
  final expenseScheduleVat = <String, Map<String, Object?>?>{};

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

  /// (workspaceId, packageId) of buy_package calls.
  final boughtPackages = <(String, String)>[];

  /// Providers the fake deployment offers; empty models "not configured".
  List<PaymentProvider> paymentProviders = [PaymentProvider.paypal];

  /// Per-provider missing env vars reported by the config probe.
  Map<String, List<String>> paymentMissing = const {};

  /// (provider, amountCents) of createPaymentOrder calls.
  final paymentOrders = <(PaymentProvider, int)>[];

  /// Approval URL the fake returns; null models an unconfigured provider.
  Uri? paymentApprovalUrl;

  /// Per-provider server config the owner UI reads back.
  final Map<PaymentProvider, PaymentProviderStatus> paymentStatus = {};

  /// (provider, config) of setPaymentCredentials calls.
  final savedPaymentConfigs = <(PaymentProvider, Map<String, String>)>[];
  final clearedProviders = <PaymentProvider>[];

  /// What [recordServiceCharge] and [buyPackage] stamp when the item has no
  /// rate of its own — the fake's stand-in for
  /// `workspace_default_vat_percent`.
  double get _defaultVatPercent => vatRates
      .where((r) => r.active && r.isDefault)
      .map((r) => r.percent)
      .firstOrNull ??
      0;

  // #2386 — the operations; each body is in a part file.
  @override Future<List<VatDeclaration>> fetchVatDeclarations(String workspaceId) => _fetchVatDeclarationsImpl(workspaceId);
  @override Future<String> saveVatDeclaration({required String workspaceId, required DateTime periodStart, required DateTime periodEnd}) => _saveVatDeclarationImpl(workspaceId: workspaceId, periodStart: periodStart, periodEnd: periodEnd);
  @override Future<void> markVatDeclarationSubmitted({required String declarationId, required String channel, required String receipt}) => _markVatDeclarationSubmittedImpl(declarationId: declarationId, channel: channel, receipt: receipt);
  @override Future<List<String>> listReportImages(String workspaceId) => _listReportImagesImpl(workspaceId);
  @override Future<void> uploadReportImage(String workspaceId, {required String name, required List<int> bytes, required String contentType}) => _uploadReportImageImpl(workspaceId, name: name, bytes: bytes, contentType: contentType);
  @override Future<Uint8List?> fetchReportImage(String workspaceId, String name) => _fetchReportImageImpl(workspaceId, name);
  @override Future<List<Invoice>> fetchInvoices(String workspaceId) => _fetchInvoicesImpl(workspaceId);
  @override Future<InvoicePdfTemplate> fetchInvoicePdfTemplate(String workspaceId) => _fetchInvoicePdfTemplateImpl(workspaceId);
  @override Future<void> setInvoicePdfTemplate(String workspaceId, InvoicePdfTemplate template) => _setInvoicePdfTemplateImpl(workspaceId, template);
  @override Future<PriceNegotiation> fetchPriceNegotiation(String memberId) => _fetchPriceNegotiationImpl(memberId);
  @override Future<void> proposePriceNegotiation({required String memberId, int? feeCents, int? overageFeeCents, double? discountPercent, String note = '', DateTime? validFrom, int? subscriptionPct, Map<String, Map<String, int>> items = const {}}) => _proposePriceNegotiationImpl(memberId: memberId, feeCents: feeCents, overageFeeCents: overageFeeCents, discountPercent: discountPercent, note: note, validFrom: validFrom, subscriptionPct: subscriptionPct, items: items);
  @override Future<int> sweepPaymentReminders(String workspaceId) => _sweepPaymentRemindersImpl(workspaceId);
  @override Future<DunningRules> fetchDunningRules(String workspaceId) => _fetchDunningRulesImpl(workspaceId);
  @override Future<void> setDunningRules(String workspaceId, DunningRules rules) => _setDunningRulesImpl(workspaceId, rules);
  @override Future<String> verifyInvoiceSignature(String invoiceId) => _verifyInvoiceSignatureImpl(invoiceId);
  @override Future<List<NumberSequence>> fetchNumberSequences(String workspaceId) => _fetchNumberSequencesImpl(workspaceId);
  @override Future<void> setNumberSequence(String workspaceId, NumberSequence sequence, {int? raiseNextValueTo}) => _setNumberSequenceImpl(workspaceId, sequence, raiseNextValueTo: raiseNextValueTo);
  @override Future<String> previewDocumentNumber(String workspaceId, String journal) => _previewDocumentNumberImpl(workspaceId, journal);
  @override Future<String> settleInvoices({required String workspaceId, required String memberId, required List<String> invoiceIds, String note = ''}) => _settleInvoicesImpl(workspaceId: workspaceId, memberId: memberId, invoiceIds: invoiceIds, note: note);
  @override Future<BillingRules> fetchBillingRules(String workspaceId) => _fetchBillingRulesImpl(workspaceId);
  @override Future<void> setBillingRules(String workspaceId, BillingRules rules) => _setBillingRulesImpl(workspaceId, rules);
  @override Future<WorkspaceStatus> fetchWorkspaceStatus(String workspaceId, String from, String to) => _fetchWorkspaceStatusImpl(workspaceId, from, to);
  @override Future<RepartitionRule> fetchRepartitionRule(String workspaceId) => _fetchRepartitionRuleImpl(workspaceId);
  @override Future<void> setRepartitionRule(String workspaceId, RepartitionRule rule) => _setRepartitionRuleImpl(workspaceId, rule);
  @override Future<int> sweepBillingInvoices(String workspaceId) => _sweepBillingInvoicesImpl(workspaceId);
  List<InvoiceLine> derivedLines(String memberId, String period) => _derivedLinesImpl(memberId, period);
  @override Future<List<String>> invoiceIssueReadiness({required String workspaceId, required String memberId, required String period, InvoiceKind kind = InvoiceKind.full, String? replacesId}) => _invoiceIssueReadinessImpl(workspaceId: workspaceId, memberId: memberId, period: period, kind: kind, replacesId: replacesId);
  @override Future<String> createInvoice({required String workspaceId, required String memberId, required String period, String? replacesId, bool detailed = false, InvoiceKind kind = InvoiceKind.full, String buyerReference = '', String purchaseOrder = ''}) => _createInvoiceImpl(workspaceId: workspaceId, memberId: memberId, period: period, replacesId: replacesId, detailed: detailed, kind: kind, buyerReference: buyerReference, purchaseOrder: purchaseOrder);
  @override Future<void> voidInvoice(String invoiceId) => _voidInvoiceImpl(invoiceId);
  @override Future<void> remindInvoice(String invoiceId) => _remindInvoiceImpl(invoiceId);
  @override Future<List<ReminderEvidence>> fetchReminderEvidence(String invoiceId) => _fetchReminderEvidenceImpl(invoiceId);
  @override Future<Map<String, String>> fetchDunningHolds(String workspaceId) => _fetchDunningHoldsImpl(workspaceId);
  @override Future<void> placeDunningHold(String invoiceId, {required String reason, String note = ''}) => _placeDunningHoldImpl(invoiceId, reason: reason, note: note);
  @override Future<void> releaseDunningHold(String invoiceId) => _releaseDunningHoldImpl(invoiceId);
  @override Future<void> settleCreditInvoice(String invoiceId, {String note = ''}) => _settleCreditInvoiceImpl(invoiceId, note: note);
  @override Future<Map<String, List<TaxPointPayment>>> fetchInvoiceInstalments(String workspaceId) => _fetchInvoiceInstalmentsImpl(workspaceId);
  @override Future<Set<String>> fetchConsumedPaymentIds(String workspaceId) => _fetchConsumedPaymentIdsImpl(workspaceId);
  String seedPayment(String memberId, int amountCents, {String description = '', String? period}) => _seedPaymentImpl(memberId, amountCents, description: description, period: period);
  String seedCreditNote(String memberId, int amountCents, {String description = 'Credit note', String? period}) => _seedCreditNoteImpl(memberId, amountCents, description: description, period: period);
  @override Future<void> matchInvoice({required String invoiceId, required String paymentLedgerId, required String resolution, String note = ''}) => _matchInvoiceImpl(invoiceId: invoiceId, paymentLedgerId: paymentLedgerId, resolution: resolution, note: note);
  UsageRecord seedUsage({required int reservedMinutes, int? actualMinutes, String memberId = 'member-1', String period = '2026-08', String space = 'Desk A1'}) => _seedUsageImpl(reservedMinutes: reservedMinutes, actualMinutes: actualMinutes, memberId: memberId, period: period, space: space);
  @override Future<List<UsageRecord>> fetchUsageRecords({required String workspaceId, required String period, String? memberId}) => _fetchUsageRecordsImpl(workspaceId: workspaceId, period: period, memberId: memberId);
  @override Future<String> requestUsageCorrection(String recordId, {String reason = ''}) => _requestUsageCorrectionImpl(recordId, reason: reason);
  @override Future<String> requestUsageRecordDelete(String recordId, {String reason = ''}) => _requestUsageRecordDeleteImpl(recordId, reason: reason);
  @override Future<Map<String, InvoiceMatch>> fetchInvoiceMatches(String workspaceId) => _fetchInvoiceMatchesImpl(workspaceId);
  @override Future<Statement> fetchStatement(String memberId, String period) => _fetchStatementImpl(memberId, period);
  @override Future<MemberAccount> fetchMemberAccount(String memberId) => _fetchMemberAccountImpl(memberId);
  @override Future<String> distributeExpense({required String workspaceId, required String title, required int amountCents, required RepartitionMethod method, required String period, required List<RepartitionShare> shares, String? sourceEventId}) => _distributeExpenseImpl(workspaceId: workspaceId, title: title, amountCents: amountCents, method: method, period: period, shares: shares, sourceEventId: sourceEventId);
  @override Future<List<ExpenseRepartition>> fetchExpenseRepartitions(String workspaceId) => _fetchExpenseRepartitionsImpl(workspaceId);
  @override Future<List<LedgerEntry>> fetchWorkspaceLedger(String workspaceId) => _fetchWorkspaceLedgerImpl(workspaceId);
  @override Future<List<PaymentIntent>> fetchPaymentIntents(String workspaceId) => _fetchPaymentIntentsImpl(workspaceId);
  @override Future<List<LedgerEntry>> fetchLedger(String memberId) => _fetchLedgerImpl(memberId);
  @override Future<String> recordPayment({required String workspaceId, required String memberId, required int amountCents, String note = '', PaymentMethod? method, DateTime? paidOn, String? period}) => _recordPaymentImpl(workspaceId: workspaceId, memberId: memberId, amountCents: amountCents, note: note, method: method, paidOn: paidOn, period: period);
  @override Future<EInvoiceGatewayConfig> fetchEInvoiceGateway(String workspaceId) => _fetchEInvoiceGatewayImpl(workspaceId);
  @override Future<EInvoiceSubmission> sendEInvoice({required String workspaceId, required String invoiceId, required String fileName, required String mimeType, required List<int> bytes, String environment = 'prod', String destination = 'government', String format = '', String receiverScheme = '', String receiverId = ''}) => _sendEInvoiceImpl(workspaceId: workspaceId, invoiceId: invoiceId, fileName: fileName, mimeType: mimeType, bytes: bytes, environment: environment, destination: destination, format: format, receiverScheme: receiverScheme, receiverId: receiverId);
  @override Future<EInvoiceSubmission> requestEInvoiceReceipt({required String workspaceId, required String transmissionId}) => _requestEInvoiceReceiptImpl(workspaceId: workspaceId, transmissionId: transmissionId);
  @override Future<Map<String, InvoiceTransmission>> fetchInvoiceTransmissions(String workspaceId) => _fetchInvoiceTransmissionsImpl(workspaceId);
  @override Future<void> setEInvoiceCredentials(String workspaceId, Map<String, String> config) => _setEInvoiceCredentialsImpl(workspaceId, config);
  @override Future<void> clearEInvoiceCredentials(String workspaceId) => _clearEInvoiceCredentialsImpl(workspaceId);
  @override Future<EInvoiceProviderStatus> fetchEInvoiceStatus(String workspaceId) => _fetchEInvoiceStatusImpl(workspaceId);
  @override Future<List<FeeBand>> fetchFeeBands(String workspaceId) => _fetchFeeBandsImpl(workspaceId);
  @override Future<void> replaceFeeBands(String workspaceId, List<FeeBand> bands) => _replaceFeeBandsImpl(workspaceId, bands);
  @override Future<SubscriptionLevels> fetchSubscriptionLevels(String workspaceId) => _fetchSubscriptionLevelsImpl(workspaceId);
  @override Future<void> setSubscriptionLevels(String workspaceId, SubscriptionLevels levels) => _setSubscriptionLevelsImpl(workspaceId, levels);
  @override Future<List<VatRate>> fetchVatRates(String workspaceId) => _fetchVatRatesImpl(workspaceId);
  @override Future<void> setVatRates(String workspaceId, List<VatRate> rates) => _setVatRatesImpl(workspaceId, rates);
  @override Future<List<ServiceItem>> fetchServices(String workspaceId, {bool includeInactive = false}) => _fetchServicesImpl(workspaceId, includeInactive: includeInactive);
  @override Future<ServiceItem> createService(String workspaceId, {required String name, required int priceCents, String? vatRateId, SupplyClass supplyClass = SupplyClass.property}) => _createServiceImpl(workspaceId, name: name, priceCents: priceCents, vatRateId: vatRateId, supplyClass: supplyClass);
  @override Future<ServiceItem> updateService(String serviceId, {String? name, int? priceCents, bool? active, String? vatRateId, SupplyClass? supplyClass}) => _updateServiceImpl(serviceId, name: name, priceCents: priceCents, active: active, vatRateId: vatRateId, supplyClass: supplyClass);
  @override Future<void> recordServiceCharge({required String workspaceId, required String subjectMemberId, required String serviceId, required int quantity, String? period}) => _recordServiceChargeImpl(workspaceId: workspaceId, subjectMemberId: subjectMemberId, serviceId: serviceId, quantity: quantity, period: period);
  @override Future<List<ExpenseSchedule>> fetchExpenseSchedules(String workspaceId) => _fetchExpenseSchedulesImpl(workspaceId);
  @override Future<String> createExpenseSchedule({required String workspaceId, required String title, required int amountCents, required DateTime startsOn, required ScheduleUnit unit, int every = 1, int? repeatCount, DateTime? endsOn, String description = ''}) => _createExpenseScheduleImpl(workspaceId: workspaceId, title: title, amountCents: amountCents, startsOn: startsOn, unit: unit, every: every, repeatCount: repeatCount, endsOn: endsOn, description: description);
  @override Future<void> cancelExpenseSchedule(String scheduleId) => _cancelExpenseScheduleImpl(scheduleId);
  @override Future<void> setExpenseScheduleVat(String scheduleId, Map<String, Object?>? vat) async => expenseScheduleVat[scheduleId] = vat;
  @override Future<int> sweepExpenseSchedules(String workspaceId) => _sweepExpenseSchedulesImpl(workspaceId);
  @override Future<List<ExpenseOccurrence>> fetchExpenseOccurrences(String workspaceId) => _fetchExpenseOccurrencesImpl(workspaceId);
  @override Future<void> confirmExpenseOccurrence({required String occurrenceId, required int amountCents, String reason = '', String? note}) => _confirmExpenseOccurrenceImpl(occurrenceId: occurrenceId, amountCents: amountCents, reason: reason, note: note);
  @override Future<String> submitExpense({required String workspaceId, required int amountCents, required String category, String description = '', Map<String, Object?>? supply, Map<String, Object?>? vat}) => _submitExpenseImpl(workspaceId: workspaceId, amountCents: amountCents, category: category, description: description, supply: supply, vat: vat);
  @override Future<List<Package>> fetchPackages(String workspaceId, {bool includeInactive = false}) => _fetchPackagesImpl(workspaceId, includeInactive: includeInactive);
  @override Future<Package> createPackage(String workspaceId, {required String name, required int days, required int priceCents, String? vatRateId}) => _createPackageImpl(workspaceId, name: name, days: days, priceCents: priceCents, vatRateId: vatRateId);
  @override Future<Package> updatePackage(String packageId, {String? name, int? days, int? priceCents, bool? active, String? vatRateId}) => _updatePackageImpl(packageId, name: name, days: days, priceCents: priceCents, active: active, vatRateId: vatRateId);
  @override Future<String> buyPackage(String workspaceId, String packageId) => _buyPackageImpl(workspaceId, packageId);
  @override Future<PaymentGatewayConfig> fetchPaymentConfig(String workspaceId) => _fetchPaymentConfigImpl(workspaceId);
  @override Future<Map<PaymentProvider, PaymentProviderStatus>> fetchPaymentGatewayStatus(String workspaceId) => _fetchPaymentGatewayStatusImpl(workspaceId);
  @override Future<void> setPaymentCredentials(String workspaceId, PaymentProvider provider, Map<String, String> config) => _setPaymentCredentialsImpl(workspaceId, provider, config);
  @override Future<void> clearPaymentProvider(String workspaceId, PaymentProvider provider) => _clearPaymentProviderImpl(workspaceId, provider);
  @override Future<PaymentOrderStart> createPaymentOrder({required PaymentProvider provider, required String workspaceId, required String memberId, required int amountCents, required String currencyCode, required String period, String? requestId}) => _createPaymentOrderImpl(provider: provider, workspaceId: workspaceId, memberId: memberId, amountCents: amountCents, currencyCode: currencyCode, period: period, requestId: requestId);

}
