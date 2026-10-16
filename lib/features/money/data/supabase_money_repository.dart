// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert' show base64Encode;
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/json_reader.dart';
import '../../../core/data/paged_fetch.dart';
import '../../../core/data/system_columns.dart';
import '../../../core/time/date_text.dart';
import '../../../core/vat/supply_class.dart';
import '../domain/billing_rules.dart';
import '../domain/dunning.dart';
import '../domain/einvoice_gateway.dart';
import '../domain/expense_repartition.dart';
import '../domain/expense_schedule.dart';
import '../domain/fee_band.dart';
import '../domain/invoice.dart';
import '../domain/invoice_commands.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/invoice_queries.dart';
import '../domain/ledger_entry.dart';
import '../domain/member_account.dart';
import '../domain/member_account_queries.dart';
import '../domain/money_repository.dart';
import '../domain/number_sequence.dart';
import '../domain/package.dart';
import '../domain/payment_intent.dart';
import '../domain/payment_method.dart';
import '../domain/payment_provider.dart';
import '../domain/price_negotiation.dart';
import '../domain/reminder_evidence.dart';
import '../domain/report_template_repository.dart';
import '../domain/service_item.dart';
import '../domain/statement.dart';
import '../domain/subscription_levels.dart';
import '../domain/tax_reporting_repository.dart';
import '../domain/usage_record.dart';
import '../domain/vat_declaration.dart';
import '../domain/vat_rate.dart';
import '../domain/vat_tax_point.dart';
import '../domain/workspace_status.dart';
import 'supabase_invoice_commands.dart';
import 'supabase_invoice_queries.dart';
import 'supabase_member_account_queries.dart';
import 'supabase_report_template_repository.dart';
import 'supabase_tax_reporting_repository.dart';

part 'supabase_money_repository_part1.dart';
part 'supabase_money_repository_part2.dart';
part 'supabase_money_repository_part3.dart';
part 'supabase_money_repository_part4.dart';

class SupabaseMoneyRepository implements MoneyRepository {

  /// The invoice and account reads are their own objects (#2591 C1); this
  /// class keeps delegating to them until the remaining groups move.
  SupabaseMoneyRepository(
    this._client, {
    InvoiceQueries? invoices,
    MemberAccountQueries? accounts,
    ReportTemplateRepository? templates,
    InvoiceCommands? commands,
    TaxReportingRepository? tax,
  })  : _invoices = invoices ?? SupabaseInvoiceQueries(_client),
        _accounts = accounts ?? SupabaseMemberAccountQueries(_client),
        _templates = templates ?? SupabaseReportTemplateRepository(_client),
        _commands = commands ?? SupabaseInvoiceCommands(_client),
        _tax = tax ?? SupabaseTaxReportingRepository(_client);

  final SupabaseClient _client;
  final InvoiceQueries _invoices;
  final MemberAccountQueries _accounts;
  final ReportTemplateRepository _templates;
  final InvoiceCommands _commands;
  final TaxReportingRepository _tax;

  @override
  Future<({List<InvoiceLine> lines, int totalCents})> previewInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
  }) =>
      _invoices.previewInvoice(
          workspaceId: workspaceId, memberId: memberId, period: period);

  @override
  Future<Map<String, ({int count, DateTime last})>> fetchInvoiceReminders(
    String workspaceId,
  ) =>
      _invoices.fetchInvoiceReminders(workspaceId);

  // #2386 — the operations; each body is in a part file.
  @override Future<List<Invoice>> fetchInvoices(String workspaceId) => _invoices.fetchInvoices(workspaceId);
  @override Future<List<VatDeclaration>> fetchVatDeclarations(String workspaceId) => _tax.fetchVatDeclarations(workspaceId);
  @override Future<String> saveVatDeclaration({required String workspaceId, required DateTime periodStart, required DateTime periodEnd}) => _tax.saveVatDeclaration(workspaceId: workspaceId, periodStart: periodStart, periodEnd: periodEnd);
  @override Future<void> markVatDeclarationSubmitted({required String declarationId, required String channel, required String receipt}) => _tax.markVatDeclarationSubmitted(declarationId: declarationId, channel: channel, receipt: receipt);
  @override Future<InvoicePdfTemplate> fetchInvoicePdfTemplate(String workspaceId) => _templates.fetchInvoicePdfTemplate(workspaceId);
  @override Future<void> setInvoicePdfTemplate(String workspaceId, InvoicePdfTemplate template) => _templates.setInvoicePdfTemplate(workspaceId, template);
  @override Future<List<String>> listReportImages(String workspaceId) => _templates.listReportImages(workspaceId);
  @override Future<void> uploadReportImage(String workspaceId, {required String name, required List<int> bytes, required String contentType}) => _templates.uploadReportImage(workspaceId, name: name, bytes: bytes, contentType: contentType);
  @override Future<Uint8List?> fetchReportImage(String workspaceId, String name) => _templates.fetchReportImage(workspaceId, name);
  @override Future<void> settleCreditInvoice(String invoiceId, {String note = ''}) => _commands.settleCreditInvoice(invoiceId, note: note);
  @override Future<Set<String>> fetchConsumedPaymentIds(String workspaceId) => _invoices.fetchConsumedPaymentIds(workspaceId);
  @override Future<MemberAccount> fetchMemberAccount(String memberId) => _accounts.fetchMemberAccount(memberId);
  @override Future<DunningRules> fetchDunningRules(String workspaceId) => _fetchDunningRulesImpl(workspaceId);
  @override Future<String> settleInvoices({required String workspaceId, required String memberId, required List<String> invoiceIds, String note = ''}) => _commands.settleInvoices(workspaceId: workspaceId, memberId: memberId, invoiceIds: invoiceIds, note: note);
  @override Future<BillingRules> fetchBillingRules(String workspaceId) => _fetchBillingRulesImpl(workspaceId);
  @override Future<WorkspaceStatus> fetchWorkspaceStatus(String workspaceId, String from, String to) => _fetchWorkspaceStatusImpl(workspaceId, from, to);
  @override Future<RepartitionRule> fetchRepartitionRule(String workspaceId) => _fetchRepartitionRuleImpl(workspaceId);
  @override Future<void> setRepartitionRule(String workspaceId, RepartitionRule rule) => _setRepartitionRuleImpl(workspaceId, rule);
  @override Future<void> setBillingRules(String workspaceId, BillingRules rules) => _setBillingRulesImpl(workspaceId, rules);
  @override Future<int> sweepBillingInvoices(String workspaceId) => _sweepBillingInvoicesImpl(workspaceId);
  @override Future<PriceNegotiation> fetchPriceNegotiation(String memberId) => _fetchPriceNegotiationImpl(memberId);
  @override Future<void> proposePriceNegotiation({required String memberId, int? feeCents, int? overageFeeCents, double? discountPercent, String note = '', DateTime? validFrom, int? subscriptionPct, Map<String, Map<String, int>> items = const {}}) => _proposePriceNegotiationImpl(memberId: memberId, feeCents: feeCents, overageFeeCents: overageFeeCents, discountPercent: discountPercent, note: note, validFrom: validFrom, subscriptionPct: subscriptionPct, items: items);
  @override Future<int> sweepPaymentReminders(String workspaceId) => _sweepPaymentRemindersImpl(workspaceId);
  @override Future<void> setDunningRules(String workspaceId, DunningRules rules) => _setDunningRulesImpl(workspaceId, rules);
  @override Future<String> verifyInvoiceSignature(String invoiceId) => _verifyInvoiceSignatureImpl(invoiceId);
  @override Future<List<NumberSequence>> fetchNumberSequences(String workspaceId) => _fetchNumberSequencesImpl(workspaceId);
  @override Future<void> setNumberSequence(String workspaceId, NumberSequence sequence, {int? raiseNextValueTo}) => _setNumberSequenceImpl(workspaceId, sequence, raiseNextValueTo: raiseNextValueTo);
  @override Future<String> previewDocumentNumber(String workspaceId, String journal) => _previewDocumentNumberImpl(workspaceId, journal);
  @override Future<String> distributeExpense({required String workspaceId, required String title, required int amountCents, required RepartitionMethod method, required String period, required List<RepartitionShare> shares, String? sourceEventId}) => _distributeExpenseImpl(workspaceId: workspaceId, title: title, amountCents: amountCents, method: method, period: period, shares: shares, sourceEventId: sourceEventId);
  @override Future<List<UsageRecord>> fetchUsageRecords({required String workspaceId, required String period, String? memberId}) => _accounts.fetchUsageRecords(workspaceId: workspaceId, period: period, memberId: memberId);
  @override Future<String> requestUsageCorrection(String recordId, {String reason = ''}) => _requestUsageCorrectionImpl(recordId, reason: reason);
  @override Future<String> requestUsageRecordDelete(String recordId, {String reason = ''}) => _requestUsageRecordDeleteImpl(recordId, reason: reason);
  @override Future<List<ExpenseRepartition>> fetchExpenseRepartitions(String workspaceId) => _fetchExpenseRepartitionsImpl(workspaceId);
  @override Future<String> createInvoice({required String workspaceId, required String memberId, required String period, String? replacesId, bool detailed = false, InvoiceKind kind = InvoiceKind.full, String buyerReference = '', String purchaseOrder = '', String correctionReason = ''}) => _commands.createInvoice(workspaceId: workspaceId, memberId: memberId, period: period, replacesId: replacesId, detailed: detailed, kind: kind, buyerReference: buyerReference, purchaseOrder: purchaseOrder, correctionReason: correctionReason);
  @override Future<List<String>> invoiceIssueReadiness({required String workspaceId, required String memberId, required String period, InvoiceKind kind = InvoiceKind.full, String? replacesId, String correctionReason = ''}) => _invoices.invoiceIssueReadiness(workspaceId: workspaceId, memberId: memberId, period: period, kind: kind, replacesId: replacesId, correctionReason: correctionReason);
  @override Future<void> voidInvoice(String invoiceId) => _commands.voidInvoice(invoiceId);
  @override Future<void> remindInvoice(String invoiceId) => _commands.remindInvoice(invoiceId);
  @override Future<Map<String, String>> fetchDunningHolds(String workspaceId) => _fetchDunningHoldsImpl(workspaceId);
  @override Future<void> placeDunningHold(String invoiceId, {required String reason, String note = ''}) => _placeDunningHoldImpl(invoiceId, reason: reason, note: note);
  @override Future<void> releaseDunningHold(String invoiceId) => _releaseDunningHoldImpl(invoiceId);
  @override Future<void> matchInvoice({required String invoiceId, required String paymentLedgerId, required String resolution, String note = ''}) => _commands.matchInvoice(invoiceId: invoiceId, paymentLedgerId: paymentLedgerId, resolution: resolution, note: note);
  @override Future<Map<String, InvoiceMatch>> fetchInvoiceMatches(String workspaceId) => _invoices.fetchInvoiceMatches(workspaceId);
  @override Future<Map<String, List<TaxPointPayment>>> fetchInvoiceInstalments(String workspaceId) => _invoices.fetchInvoiceInstalments(workspaceId);
  @override Future<List<ReminderEvidence>> fetchReminderEvidence(String invoiceId) => _invoices.fetchReminderEvidence(invoiceId);
  @override Future<Statement> fetchStatement(String memberId, String period) => _accounts.fetchStatement(memberId, period);
  @override Future<List<LedgerEntry>> fetchLedger(String memberId) => _accounts.fetchLedger(memberId);
  @override Future<List<LedgerEntry>> fetchWorkspaceLedger(String workspaceId) => _accounts.fetchWorkspaceLedger(workspaceId);
  @override Future<List<PaymentIntent>> fetchPaymentIntents(String workspaceId) => _fetchPaymentIntentsImpl(workspaceId);
  @override Future<String> recordPayment({required String workspaceId, required String memberId, required int amountCents, String note = '', PaymentMethod? method, DateTime? paidOn, String? period}) => _recordPaymentImpl(workspaceId: workspaceId, memberId: memberId, amountCents: amountCents, note: note, method: method, paidOn: paidOn, period: period);
  @override Future<void> recordServiceCharge({required String workspaceId, required String subjectMemberId, required String serviceId, required int quantity, String? period}) => _recordServiceChargeImpl(workspaceId: workspaceId, subjectMemberId: subjectMemberId, serviceId: serviceId, quantity: quantity, period: period);
  @override Future<List<ExpenseSchedule>> fetchExpenseSchedules(String workspaceId) => _fetchExpenseSchedulesImpl(workspaceId);
  @override Future<String> createExpenseSchedule({required String workspaceId, required String title, required int amountCents, required DateTime startsOn, required ScheduleUnit unit, int every = 1, int? repeatCount, DateTime? endsOn, String description = ''}) => _createExpenseScheduleImpl(workspaceId: workspaceId, title: title, amountCents: amountCents, startsOn: startsOn, unit: unit, every: every, repeatCount: repeatCount, endsOn: endsOn, description: description);
  @override Future<void> cancelExpenseSchedule(String scheduleId) => _cancelExpenseScheduleImpl(scheduleId);
  @override Future<void> setExpenseScheduleVat(String scheduleId, Map<String, Object?>? vat) => _client.rpc<void>('set_expense_schedule_vat', params: {'p_schedule_id': scheduleId, 'p_vat': vat});
  @override Future<int> sweepExpenseSchedules(String workspaceId) => _sweepExpenseSchedulesImpl(workspaceId);
  @override Future<List<ExpenseOccurrence>> fetchExpenseOccurrences(String workspaceId) => _fetchExpenseOccurrencesImpl(workspaceId);
  @override Future<void> confirmExpenseOccurrence({required String occurrenceId, required int amountCents, String reason = '', String? note}) => _confirmExpenseOccurrenceImpl(occurrenceId: occurrenceId, amountCents: amountCents, reason: reason, note: note);
  @override Future<String> submitExpense({required String workspaceId, required int amountCents, required String category, String description = '', Map<String, Object?>? supply, Map<String, Object?>? vat}) => _submitExpenseImpl(workspaceId: workspaceId, amountCents: amountCents, category: category, description: description, supply: supply, vat: vat);
  @override Future<List<FeeBand>> fetchFeeBands(String workspaceId) => _fetchFeeBandsImpl(workspaceId);
  @override Future<void> replaceFeeBands(String workspaceId, List<FeeBand> bands) => _replaceFeeBandsImpl(workspaceId, bands);
  @override Future<SubscriptionLevels> fetchSubscriptionLevels(String workspaceId) => _fetchSubscriptionLevelsImpl(workspaceId);
  @override Future<void> setSubscriptionLevels(String workspaceId, SubscriptionLevels levels) => _setSubscriptionLevelsImpl(workspaceId, levels);
  @override Future<List<VatRate>> fetchVatRates(String workspaceId) => _tax.fetchVatRates(workspaceId);
  @override Future<void> setVatRates(String workspaceId, List<VatRate> rates) => _tax.setVatRates(workspaceId, rates);
  @override Future<List<ServiceItem>> fetchServices(String workspaceId, {bool includeInactive = false}) => _fetchServicesImpl(workspaceId, includeInactive: includeInactive);
  @override Future<ServiceItem> createService(String workspaceId, {required String name, required int priceCents, String? vatRateId, SupplyClass supplyClass = SupplyClass.property}) => _createServiceImpl(workspaceId, name: name, priceCents: priceCents, vatRateId: vatRateId, supplyClass: supplyClass);
  @override Future<ServiceItem> updateService(String serviceId, {String? name, int? priceCents, bool? active, String? vatRateId, SupplyClass? supplyClass}) => _updateServiceImpl(serviceId, name: name, priceCents: priceCents, active: active, vatRateId: vatRateId, supplyClass: supplyClass);
  @override Future<List<Package>> fetchPackages(String workspaceId, {bool includeInactive = false}) => _fetchPackagesImpl(workspaceId, includeInactive: includeInactive);
  @override Future<Package> createPackage(String workspaceId, {required String name, required int days, required int priceCents, String? vatRateId}) => _createPackageImpl(workspaceId, name: name, days: days, priceCents: priceCents, vatRateId: vatRateId);
  @override Future<Package> updatePackage(String packageId, {String? name, int? days, int? priceCents, bool? active, String? vatRateId}) => _updatePackageImpl(packageId, name: name, days: days, priceCents: priceCents, active: active, vatRateId: vatRateId);
  @override Future<String> buyPackage(String workspaceId, String packageId) => _buyPackageImpl(workspaceId, packageId);
  @override Future<EInvoiceGatewayConfig> fetchEInvoiceGateway(String workspaceId) => _fetchEInvoiceGatewayImpl(workspaceId);
  @override Future<EInvoiceSubmission> sendEInvoice({required String workspaceId, required String invoiceId, required String fileName, required String mimeType, required List<int> bytes, String environment = 'prod', String destination = 'government', String format = '', String receiverScheme = '', String receiverId = ''}) => _sendEInvoiceImpl(workspaceId: workspaceId, invoiceId: invoiceId, fileName: fileName, mimeType: mimeType, bytes: bytes, environment: environment, destination: destination, format: format, receiverScheme: receiverScheme, receiverId: receiverId);
  @override Future<EInvoiceSubmission> requestEInvoiceReceipt({required String workspaceId, required String transmissionId}) => _requestEInvoiceReceiptImpl(workspaceId: workspaceId, transmissionId: transmissionId);
  @override Future<Map<String, InvoiceTransmission>> fetchInvoiceTransmissions(String workspaceId) => _fetchInvoiceTransmissionsImpl(workspaceId);
  @override Future<void> setEInvoiceCredentials(String workspaceId, Map<String, String> config) => _setEInvoiceCredentialsImpl(workspaceId, config);
  @override Future<void> clearEInvoiceCredentials(String workspaceId) => _clearEInvoiceCredentialsImpl(workspaceId);
  @override Future<EInvoiceProviderStatus> fetchEInvoiceStatus(String workspaceId) => _fetchEInvoiceStatusImpl(workspaceId);
  @override Future<PaymentGatewayConfig> fetchPaymentConfig(String workspaceId) => _fetchPaymentConfigImpl(workspaceId);
  @override Future<PaymentOrderStart> createPaymentOrder({required PaymentProvider provider, required String workspaceId, required String memberId, required int amountCents, required String currencyCode, required String period, String? requestId}) => _createPaymentOrderImpl(provider: provider, workspaceId: workspaceId, memberId: memberId, amountCents: amountCents, currencyCode: currencyCode, period: period, requestId: requestId);
  @override Future<Map<PaymentProvider, PaymentProviderStatus>> fetchPaymentGatewayStatus(String workspaceId) => _fetchPaymentGatewayStatusImpl(workspaceId);
  @override Future<void> setPaymentCredentials(String workspaceId, PaymentProvider provider, Map<String, String> config) => _setPaymentCredentialsImpl(workspaceId, provider, config);
  @override Future<void> clearPaymentProvider(String workspaceId, PaymentProvider provider) => _clearPaymentProviderImpl(workspaceId, provider);

}
