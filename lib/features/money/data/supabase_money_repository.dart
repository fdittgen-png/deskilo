// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/vat/supply_class.dart';
import '../domain/billing_rules.dart';
import '../domain/billing_rules_repository.dart';
import '../domain/commercial_terms_repository.dart';
import '../domain/document_numbering.dart';
import '../domain/dunning.dart';
import '../domain/dunning_repository.dart';
import '../domain/einvoice_gateway.dart';
import '../domain/einvoice_transmissions.dart';
import '../domain/expense_repartition.dart';
import '../domain/expense_repository.dart';
import '../domain/expense_schedule.dart';
import '../domain/fee_band.dart';
import '../domain/invoice.dart';
import '../domain/invoice_commands.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/invoice_queries.dart';
import '../domain/ledger_entry.dart';
import '../domain/member_account.dart';
import '../domain/member_account_commands.dart';
import '../domain/member_account_queries.dart';
import '../domain/money_repository.dart';
import '../domain/number_sequence.dart';
import '../domain/package.dart';
import '../domain/payment_gateway_repository.dart';
import '../domain/payment_intent.dart';
import '../domain/payment_method.dart';
import '../domain/payment_provider.dart';
import '../domain/payment_test_check.dart';
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
import 'supabase_billing_rules_repository.dart';
import 'supabase_commercial_terms_repository.dart';
import 'supabase_document_numbering.dart';
import 'supabase_dunning_repository.dart';
import 'supabase_einvoice_transmissions.dart';
import 'supabase_expense_repository.dart';
import 'supabase_invoice_commands.dart';
import 'supabase_invoice_queries.dart';
import 'supabase_member_account_commands.dart';
import 'supabase_member_account_queries.dart';
import 'supabase_payment_gateway_repository.dart';
import 'supabase_report_template_repository.dart';
import 'supabase_tax_reporting_repository.dart';

class SupabaseMoneyRepository implements MoneyRepository {

  /// Every group is its own object (#2591): this compatibility facade only
  /// hands each call to the port that owns it, and holds no client state.
  SupabaseMoneyRepository(
    SupabaseClient client, {
    InvoiceQueries? invoices,
    MemberAccountQueries? accounts,
    ReportTemplateRepository? templates,
    InvoiceCommands? commands,
    TaxReportingRepository? tax,
    CommercialTermsRepository? terms,
    ExpenseRepository? expenses,
    DunningRepository? dunning,
    BillingRulesRepository? billing,
    DocumentNumbering? numbering,
    MemberAccountCommands? accountCommands,
    PaymentGatewayRepository? payments,
    EInvoiceTransmissions? eInvoices,
  })  : _invoices = invoices ?? SupabaseInvoiceQueries(client),
        _accounts = accounts ?? SupabaseMemberAccountQueries(client),
        _templates = templates ?? SupabaseReportTemplateRepository(client),
        _commands = commands ?? SupabaseInvoiceCommands(client),
        _tax = tax ?? SupabaseTaxReportingRepository(client),
        _terms = terms ?? SupabaseCommercialTermsRepository(client),
        _expenses = expenses ?? SupabaseExpenseRepository(client),
        _dunning = dunning ?? SupabaseDunningRepository(client),
        _billing = billing ?? SupabaseBillingRulesRepository(client),
        _numbering = numbering ?? SupabaseDocumentNumbering(client),
        _accountCommands =
            accountCommands ?? SupabaseMemberAccountCommands(client),
        _payments = payments ?? SupabasePaymentGatewayRepository(client),
        _eInvoices = eInvoices ?? SupabaseEInvoiceTransmissions(client);

  final InvoiceQueries _invoices;
  final MemberAccountQueries _accounts;
  final ReportTemplateRepository _templates;
  final InvoiceCommands _commands;
  final TaxReportingRepository _tax;
  final CommercialTermsRepository _terms;
  final ExpenseRepository _expenses;
  final DunningRepository _dunning;
  final BillingRulesRepository _billing;
  final DocumentNumbering _numbering;
  final MemberAccountCommands _accountCommands;
  final PaymentGatewayRepository _payments;
  final EInvoiceTransmissions _eInvoices;

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
  @override Future<DunningRules> fetchDunningRules(String workspaceId) => _dunning.fetchDunningRules(workspaceId);
  @override Future<String> settleInvoices({required String workspaceId, required String memberId, required List<String> invoiceIds, String note = ''}) => _commands.settleInvoices(workspaceId: workspaceId, memberId: memberId, invoiceIds: invoiceIds, note: note);
  @override Future<BillingRules> fetchBillingRules(String workspaceId) => _billing.fetchBillingRules(workspaceId);
  @override Future<WorkspaceStatus> fetchWorkspaceStatus(String workspaceId, String from, String to) => _billing.fetchWorkspaceStatus(workspaceId, from, to);
  @override Future<RepartitionRule> fetchRepartitionRule(String workspaceId) => _billing.fetchRepartitionRule(workspaceId);
  @override Future<void> setRepartitionRule(String workspaceId, RepartitionRule rule) => _billing.setRepartitionRule(workspaceId, rule);
  @override Future<void> setBillingRules(String workspaceId, BillingRules rules) => _billing.setBillingRules(workspaceId, rules);
  @override Future<int> sweepBillingInvoices(String workspaceId) => _billing.sweepBillingInvoices(workspaceId);
  @override Future<PriceNegotiation> fetchPriceNegotiation(String memberId) => _terms.fetchPriceNegotiation(memberId);
  @override Future<void> proposePriceNegotiation({required String memberId, int? feeCents, int? overageFeeCents, double? discountPercent, String note = '', DateTime? validFrom, int? subscriptionPct, Map<String, Map<String, int>> items = const {}}) => _terms.proposePriceNegotiation(memberId: memberId, feeCents: feeCents, overageFeeCents: overageFeeCents, discountPercent: discountPercent, note: note, validFrom: validFrom, subscriptionPct: subscriptionPct, items: items);
  @override Future<int> sweepPaymentReminders(String workspaceId) => _dunning.sweepPaymentReminders(workspaceId);
  @override Future<void> setDunningRules(String workspaceId, DunningRules rules) => _dunning.setDunningRules(workspaceId, rules);
  @override Future<String> verifyInvoiceSignature(String invoiceId) => _numbering.verifyInvoiceSignature(invoiceId);
  @override Future<List<NumberSequence>> fetchNumberSequences(String workspaceId) => _numbering.fetchNumberSequences(workspaceId);
  @override Future<void> setNumberSequence(String workspaceId, NumberSequence sequence, {int? raiseNextValueTo}) => _numbering.setNumberSequence(workspaceId, sequence, raiseNextValueTo: raiseNextValueTo);
  @override Future<String> previewDocumentNumber(String workspaceId, String journal) => _numbering.previewDocumentNumber(workspaceId, journal);
  @override Future<String> distributeExpense({required String workspaceId, required String title, required int amountCents, required RepartitionMethod method, required String period, required List<RepartitionShare> shares, String? sourceEventId}) => _expenses.distributeExpense(workspaceId: workspaceId, title: title, amountCents: amountCents, method: method, period: period, shares: shares, sourceEventId: sourceEventId);
  @override Future<UsageRead> readUsageRecords({required String workspaceId, required String period, String? memberId}) => _accounts.readUsageRecords(workspaceId: workspaceId, period: period, memberId: memberId);
  @override Future<String> requestUsageCorrection(String recordId, {String reason = ''}) => _accountCommands.requestUsageCorrection(recordId, reason: reason);
  @override Future<String> requestUsageRecordDelete(String recordId, {String reason = ''}) => _accountCommands.requestUsageRecordDelete(recordId, reason: reason);
  @override Future<List<ExpenseRepartition>> fetchExpenseRepartitions(String workspaceId) => _expenses.fetchExpenseRepartitions(workspaceId);
  @override Future<String> issueInvoiceWithReceipt(InvoiceIssueCommand command) => _commands.issueInvoiceWithReceipt(command);
  @override Future<CommandReceipt> invoiceCommandOutcome({required String workspaceId, required String requestId}) => _invoices.invoiceCommandOutcome(workspaceId: workspaceId, requestId: requestId);
  @override Future<String> createInvoice({required String workspaceId, required String memberId, required String period, String? replacesId, bool detailed = false, InvoiceKind kind = InvoiceKind.full, String buyerReference = '', String purchaseOrder = '', String correctionReason = ''}) => _commands.createInvoice(workspaceId: workspaceId, memberId: memberId, period: period, replacesId: replacesId, detailed: detailed, kind: kind, buyerReference: buyerReference, purchaseOrder: purchaseOrder, correctionReason: correctionReason);
  @override Future<List<String>> invoiceIssueReadiness({required String workspaceId, required String memberId, required String period, InvoiceKind kind = InvoiceKind.full, String? replacesId, String correctionReason = ''}) => _invoices.invoiceIssueReadiness(workspaceId: workspaceId, memberId: memberId, period: period, kind: kind, replacesId: replacesId, correctionReason: correctionReason);
  @override Future<void> voidInvoice(String invoiceId) => _commands.voidInvoice(invoiceId);
  @override Future<void> remindInvoice(String invoiceId) => _commands.remindInvoice(invoiceId);
  @override Future<Map<String, String>> fetchDunningHolds(String workspaceId) => _dunning.fetchDunningHolds(workspaceId);
  @override Future<void> placeDunningHold(String invoiceId, {required String reason, String note = ''}) => _dunning.placeDunningHold(invoiceId, reason: reason, note: note);
  @override Future<void> releaseDunningHold(String invoiceId) => _dunning.releaseDunningHold(invoiceId);
  @override Future<void> matchInvoice({required String invoiceId, required String paymentLedgerId, required String resolution, String note = ''}) => _commands.matchInvoice(invoiceId: invoiceId, paymentLedgerId: paymentLedgerId, resolution: resolution, note: note);
  @override Future<Map<String, InvoiceMatch>> fetchInvoiceMatches(String workspaceId) => _invoices.fetchInvoiceMatches(workspaceId);
  @override Future<Map<String, List<TaxPointPayment>>> fetchInvoiceInstalments(String workspaceId) => _invoices.fetchInvoiceInstalments(workspaceId);
  @override Future<List<ReminderEvidence>> fetchReminderEvidence(String invoiceId) => _invoices.fetchReminderEvidence(invoiceId);
  @override Future<Statement> fetchStatement(String memberId, String period) => _accounts.fetchStatement(memberId, period);
  @override Future<List<LedgerEntry>> fetchLedger(String memberId) => _accounts.fetchLedger(memberId);
  @override Future<List<LedgerEntry>> fetchWorkspaceLedger(String workspaceId) => _accounts.fetchWorkspaceLedger(workspaceId);
  @override Future<bool> hasRecordedMoney(String workspaceId) => _accounts.hasRecordedMoney(workspaceId);
  @override Future<List<PaymentIntent>> fetchPaymentIntents(String workspaceId) => _payments.fetchPaymentIntents(workspaceId);
  @override Future<String> recordPayment({required String workspaceId, required String memberId, required int amountCents, String note = '', PaymentMethod? method, DateTime? paidOn, String? period}) => _accountCommands.recordPayment(workspaceId: workspaceId, memberId: memberId, amountCents: amountCents, note: note, method: method, paidOn: paidOn, period: period);
  @override Future<void> recordServiceCharge({required String workspaceId, required String subjectMemberId, required String serviceId, required int quantity, String? period}) => _accountCommands.recordServiceCharge(workspaceId: workspaceId, subjectMemberId: subjectMemberId, serviceId: serviceId, quantity: quantity, period: period);
  @override Future<List<ExpenseSchedule>> fetchExpenseSchedules(String workspaceId) => _expenses.fetchExpenseSchedules(workspaceId);
  @override Future<String> createExpenseSchedule({required String workspaceId, required String title, required int amountCents, required DateTime startsOn, required ScheduleUnit unit, int every = 1, int? repeatCount, DateTime? endsOn, String description = ''}) => _expenses.createExpenseSchedule(workspaceId: workspaceId, title: title, amountCents: amountCents, startsOn: startsOn, unit: unit, every: every, repeatCount: repeatCount, endsOn: endsOn, description: description);
  @override Future<void> cancelExpenseSchedule(String scheduleId) => _expenses.cancelExpenseSchedule(scheduleId);
  @override Future<void> setExpenseScheduleVat(String scheduleId, Map<String, Object?>? vat) => _expenses.setExpenseScheduleVat(scheduleId, vat);
  @override Future<void> setExpenseScheduleSupplier(String scheduleId, String? supplierId) => _expenses.setExpenseScheduleSupplier(scheduleId, supplierId);
  @override Future<int> sweepExpenseSchedules(String workspaceId) => _expenses.sweepExpenseSchedules(workspaceId);
  @override Future<List<ExpenseOccurrence>> fetchExpenseOccurrences(String workspaceId) => _expenses.fetchExpenseOccurrences(workspaceId);
  @override Future<void> confirmExpenseOccurrence({required String occurrenceId, required int amountCents, String reason = '', String? note}) => _expenses.confirmExpenseOccurrence(occurrenceId: occurrenceId, amountCents: amountCents, reason: reason, note: note);
  @override Future<String> submitExpense({required String workspaceId, required int amountCents, required String category, String description = '', Map<String, Object?>? supply, Map<String, Object?>? vat}) => _expenses.submitExpense(workspaceId: workspaceId, amountCents: amountCents, category: category, description: description, supply: supply, vat: vat);
  @override Future<List<FeeBand>> fetchFeeBands(String workspaceId) => _terms.fetchFeeBands(workspaceId);
  @override Future<void> replaceFeeBands(String workspaceId, List<FeeBand> bands) => _terms.replaceFeeBands(workspaceId, bands);
  @override Future<SubscriptionLevels> fetchSubscriptionLevels(String workspaceId) => _terms.fetchSubscriptionLevels(workspaceId);
  @override Future<void> setSubscriptionLevels(String workspaceId, SubscriptionLevels levels) => _terms.setSubscriptionLevels(workspaceId, levels);
  @override Future<List<VatRate>> fetchVatRates(String workspaceId) => _tax.fetchVatRates(workspaceId);
  @override Future<void> setVatRates(String workspaceId, List<VatRate> rates) => _tax.setVatRates(workspaceId, rates);
  @override Future<List<ServiceItem>> fetchServices(String workspaceId, {bool includeInactive = false}) => _terms.fetchServices(workspaceId, includeInactive: includeInactive);
  @override Future<ServiceItem> createService(String workspaceId, {required String name, required int priceCents, String? vatRateId, SupplyClass supplyClass = SupplyClass.property}) => _terms.createService(workspaceId, name: name, priceCents: priceCents, vatRateId: vatRateId, supplyClass: supplyClass);
  @override Future<ServiceItem> updateService(String serviceId, {String? name, int? priceCents, bool? active, String? vatRateId, SupplyClass? supplyClass}) => _terms.updateService(serviceId, name: name, priceCents: priceCents, active: active, vatRateId: vatRateId, supplyClass: supplyClass);
  @override Future<List<Package>> fetchPackages(String workspaceId, {bool includeInactive = false}) => _terms.fetchPackages(workspaceId, includeInactive: includeInactive);
  @override Future<Package> createPackage(String workspaceId, {required String name, required int days, required int priceCents, String? vatRateId}) => _terms.createPackage(workspaceId, name: name, days: days, priceCents: priceCents, vatRateId: vatRateId);
  @override Future<Package> updatePackage(String packageId, {String? name, int? days, int? priceCents, bool? active, String? vatRateId}) => _terms.updatePackage(packageId, name: name, days: days, priceCents: priceCents, active: active, vatRateId: vatRateId);
  @override Future<String> buyPackage(String workspaceId, String packageId) => _accountCommands.buyPackage(workspaceId, packageId);
  @override Future<EInvoiceGatewayConfig> fetchEInvoiceGateway(String workspaceId) => _eInvoices.fetchEInvoiceGateway(workspaceId);
  @override Future<EInvoiceSubmission> sendEInvoice({required String workspaceId, required String invoiceId, required String fileName, required String mimeType, required List<int> bytes, String environment = 'prod', String destination = 'government', String format = '', String receiverScheme = '', String receiverId = ''}) => _eInvoices.sendEInvoice(workspaceId: workspaceId, invoiceId: invoiceId, fileName: fileName, mimeType: mimeType, bytes: bytes, environment: environment, destination: destination, format: format, receiverScheme: receiverScheme, receiverId: receiverId);
  @override Future<EInvoiceSubmission> requestEInvoiceReceipt({required String workspaceId, required String transmissionId}) => _eInvoices.requestEInvoiceReceipt(workspaceId: workspaceId, transmissionId: transmissionId);
  @override Future<Map<String, InvoiceTransmission>> fetchInvoiceTransmissions(String workspaceId) => _eInvoices.fetchInvoiceTransmissions(workspaceId);
  @override Future<void> setEInvoiceCredentials(String workspaceId, Map<String, String> config) => _eInvoices.setEInvoiceCredentials(workspaceId, config);
  @override Future<void> clearEInvoiceCredentials(String workspaceId) => _eInvoices.clearEInvoiceCredentials(workspaceId);
  @override Future<EInvoiceProviderStatus> fetchEInvoiceStatus(String workspaceId) => _eInvoices.fetchEInvoiceStatus(workspaceId);
  @override Future<PaymentGatewayConfig> fetchPaymentConfig(String workspaceId) => _payments.fetchPaymentConfig(workspaceId);
  @override Future<PaymentOrderStart> createPaymentOrder({required PaymentProvider provider, required String workspaceId, required String memberId, required int amountCents, required String currencyCode, required String period, String? requestId}) => _payments.createPaymentOrder(provider: provider, workspaceId: workspaceId, memberId: memberId, amountCents: amountCents, currencyCode: currencyCode, period: period, requestId: requestId);
  @override Future<Map<PaymentProvider, PaymentProviderStatus>> fetchPaymentGatewayStatus(String workspaceId) => _payments.fetchPaymentGatewayStatus(workspaceId);
  @override Future<PaymentTestCheck> testPaymentKeys(String workspaceId) => _payments.testPaymentKeys(workspaceId);
  @override Future<void> setPaymentCredentials(String workspaceId, PaymentProvider provider, Map<String, String> config) => _payments.setPaymentCredentials(workspaceId, provider, config);
  @override Future<void> clearPaymentProvider(String workspaceId, PaymentProvider provider) => _payments.clearPaymentProvider(workspaceId, provider);
}
