// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'einvoice_gateway.dart';
import 'vat_rate.dart';
import 'fee_band.dart';

import 'invoice.dart';
import 'vat_declaration.dart';
import 'member_account.dart';
import 'dunning.dart';
import 'invoice_pdf_template.dart';import 'ledger_entry.dart';
import 'package.dart';
import 'payment_intent.dart';
import 'payment_method.dart';
import 'payment_provider.dart';
import 'service_item.dart';
import 'statement.dart';
import 'subscription_levels.dart';

/// Money boundary (spec §7). Payments are only *recorded* — the pending
/// event created by [recordPayment] must be confirmed by the other side
/// before a ledger credit exists.
abstract class MoneyRepository {
  /// The invoice archive (0060): the member's own invoices — admins see
  /// everyone's (RLS decides).
  Future<List<Invoice>> fetchInvoices(String workspaceId);

  /// The workspace's VAT declarations (0107), newest period first.
  Future<List<VatDeclaration>> fetchVatDeclarations(String workspaceId);

  /// Creates or regenerates the DRAFT declaration for a period (0107) —
  /// numbers computed client-side with the invoices' own vatSplit.
  Future<String> saveVatDeclaration({
    required String workspaceId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<VatDeclarationLine> lines,
    required int totalNetCents,
    required int totalVatCents,
    required String currency,
    required int invoiceCount,
  });

  /// Stamps a draft submitted (channel: platform | export | manual).
  Future<void> markVatDeclarationSubmitted({
    required String declarationId,
    required String channel,
    String receipt = '',
  });

  /// Transmits the declaration document through the configured
  /// e-invoicing platform channel (#534) — an accepted upload stamps
  /// the declaration submitted server-side with the receipt.
  Future<EInvoiceSubmission> sendVatDeclaration({
    required String workspaceId,
    required String declarationId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  });

  /// The workspace's invoice-PDF template (#454, 0088); empty when the
  /// column holds no keys.
  Future<InvoicePdfTemplate> fetchInvoicePdfTemplate(String workspaceId);

  /// Owner-only (workspaces_update RLS): replace the invoice-PDF
  /// template wholesale.
  Future<void> setInvoicePdfTemplate(
    String workspaceId,
    InvoicePdfTemplate template,
  );

  /// The workspace's report-image library (#488): file names stored
  /// under `<workspace>/report/` in the floor-plans bucket — the logo,
  /// stamps, signature scans the templates reference with `![name]`.
  Future<List<String>> listReportImages(String workspaceId);

  /// Owner-only (bucket RLS): add or replace a library image.
  Future<void> uploadReportImage(
    String workspaceId, {
    required String name,
    required List<int> bytes,
    required String contentType,
  });

  /// A library image's bytes; null when it does not exist.
  Future<Uint8List?> fetchReportImage(String workspaceId, String name);

  /// Settles a NEGATIVE invoice — a credit note the WORKSPACE pays
  /// (#508, 0102): books the payout charge and closes the avoir with
  /// resolution 'refunded' (through the invoice_payment policy).
  Future<void> settleCreditInvoice(String invoiceId, {String note = ''});

  /// Every payment already consumed by a match (#506, 0101) — the
  /// candidates list must not offer them again.
  Future<Set<String>> fetchConsumedPaymentIds(String workspaceId);

  /// The member's real cross-month position (#512): credit on account,
  /// open remainders, refunds due, net.
  Future<MemberAccount> fetchMemberAccount(String memberId);

  /// The workspace's dunning policy (#472, 0093); defaults when unset.
  Future<DunningRules> fetchDunningRules(String workspaceId);

  /// #726 — apply the dunning rules now (idempotent: the rules decide).
  /// Returns how many reminders were recorded. Admins only.
  Future<int> sweepPaymentReminders(String workspaceId);

  /// Owner-only: persist the dunning policy.
  Future<void> setDunningRules(String workspaceId, DunningRules rules);

  /// Issues an IMMUTABLE invoice (RPC `create_invoice`) — owner always,
  /// admins per the adminInvoicing delegation. Returns its id. Since
  /// 0062 the positions are DERIVED server-side from [period]'s tracked
  /// data — nothing is entered at issue time. With [replacesId] (0061)
  /// the new invoice references the erroneous one it replaces; the
  /// server voids that one in the same transaction.
  /// [detailed] (0064) snapshots the annex — the period's full ledger
  /// and attendance — into the immutable document.
  Future<String> createInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
    String? replacesId,
    bool detailed = false,
  });

  /// What [createInvoice] would issue for [period], without issuing
  /// (RPC `preview_invoice`, 0062).
  Future<({List<InvoiceLine> lines, int totalCents})> previewInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
  });

  /// Tags an invoice erroneous (RPC `void_invoice`, 0061) — the sole
  /// one-way change the server permits on an issued invoice.
  Future<void> voidInvoice(String invoiceId);

  /// Records a payment reminder (RPC `record_invoice_reminder`, 0066)
  /// — collection metadata beside the immutable document.
  Future<void> remindInvoice(String invoiceId);

  /// invoiceId → reminder count + last reminder instant (0066).
  Future<Map<String, ({int count, DateTime last})>> fetchInvoiceReminders(
    String workspaceId,
  );

  /// Matches an open invoice to a REGISTERED payment (RPC
  /// `match_invoice`, 0068): the amount comes from the selected ledger
  /// payment — never typed. [resolution] ∈ exact | over_forced |
  /// over_credit_note | under_accepted; the forced paths REQUIRE
  /// [note].
  Future<void> matchInvoice({
    required String invoiceId,
    required String paymentLedgerId,
    required String resolution,
    String note = '',
  });

  /// invoiceId → its match (0067). status 'pending' while a validation
  /// quorum decides; a reject deletes the row (the invoice reopens).
  Future<Map<String, InvoiceMatch>> fetchInvoiceMatches(String workspaceId);

  Future<Statement> fetchStatement(String memberId, String period);

  Future<List<LedgerEntry>> fetchLedger(String memberId);

  /// EVERY member's ledger of the workspace — the payments/services tabs
  /// of the data export (#395). RLS already grants admins the full table
  /// (0008); a worker calling this gets only their own rows back.
  Future<List<LedgerEntry>> fetchWorkspaceLedger(String workspaceId);

  /// All online-payment attempts of the workspace (0045) — the export's
  /// online-payments rows. Admin-readable by the 0045 policy.
  Future<List<PaymentIntent>> fetchPaymentIntents(String workspaceId);

  /// Returns the pending event id. [method] is how the money moved
  /// (#154); null = not specified (renders method-less, like pre-#154
  /// events).
  ///
  /// [paidOn] is the day the money actually moved (0070) — recording on
  /// the 26th a transfer made on the 3rd must not date it the 26th; null
  /// = today. [period] is the month the payment SETTLES, which decides
  /// which bill and which invoice it lands on; null = the current month.
  Future<String> recordPayment({
    required String workspaceId,
    required String memberId,
    required int amountCents,
    String note,
    PaymentMethod? method,
    DateTime? paidOn,
    String? period,
  });

  /// Fee bands of the workspace ordered by [FeeBand.fromPct]
  /// (member-readable, ADR 0008 / #128).
  Future<List<FeeBand>> fetchFeeBands(String workspaceId);

  /// Owner-only (RPC `replace_fee_bands`): atomically replaces the whole
  /// band set. Bands must tile (0, 100] contiguously — validated
  /// server-side too.
  Future<void> replaceFeeBands(String workspaceId, List<FeeBand> bands);

  /// The owner-curated subscription levels of the workspace (#128).
  Future<SubscriptionLevels> fetchSubscriptionLevels(String workspaceId);

  /// Owner-only (RLS on workspaces): persists the offered levels.
  Future<void> setSubscriptionLevels(
    String workspaceId,
    SubscriptionLevels levels,
  );

  /// Consumable services of the workspace, name-ordered (member-readable).
  /// Owners pass [includeInactive] for the catalog editor (#123).
  Future<List<ServiceItem>> fetchServices(
    String workspaceId, {
    bool includeInactive = false,
  });

  /// Owner-only (RLS services_write): creates a service.
  Future<ServiceItem> createService(
    String workspaceId, {
    required String name,
    required int priceCents,
    String? vatRateId,
  });

  /// Owner-only: partial update of name, price, VAT rate and active flag.
  /// Deactivate = `updateService(active: false)` — services are never
  /// deleted (bill lines reference them).
  Future<ServiceItem> updateService(
    String serviceId, {
    String? name,
    int? priceCents,
    bool? active,
    String? vatRateId,
  });

  /// The VAT rates the workspace charges (0072), member-readable: they
  /// appear on the bill and on every invoice.
  Future<List<VatRate>> fetchVatRates(String workspaceId);

  /// Owner-only (RPC `set_vat_rates`): replaces the whole rate set
  /// atomically. Exactly one rate must be the default. A rate a service
  /// still points at is deactivated rather than deleted, so no catalogue
  /// entry is ever silently re-taxed.
  Future<void> setVatRates(String workspaceId, List<VatRate> rates);

  /// Records consumed services onto the monthly bill (#129, ADR 0008).
  /// Creates a PENDING service_charge event with a name+price snapshot —
  /// the ledger charge posts only on confirmation. Members self-report
  /// (subject = self); admins/owner may record for any member. [period]
  /// is 'yyyy-MM' and defaults server-side to the current month.
  Future<void> recordServiceCharge({
    required String workspaceId,
    required String subjectMemberId,
    required String serviceId,
    required int quantity,
    String? period,
  });

  /// Submits a community expense (spec §9); another admin must approve
  /// before the credit exists. Returns the pending event id.
  Future<String> submitExpense({
    required String workspaceId,
    required int amountCents,
    required String category,
    String description,
    /// #731 — when the expense is a SUPPLY for the space: name (or
    /// service_id of an existing item), quantity, unit_price_cents.
    Map<String, Object?>? supply,
  });

  /// Owner-defined day packages (migration 0042). Members read the active
  /// ones (the buy sheet); owners pass [includeInactive] for the editor.
  Future<List<Package>> fetchPackages(
    String workspaceId, {
    bool includeInactive = false,
  });

  /// Owner-only (RLS packages_write): creates a package.
  Future<Package> createPackage(
    String workspaceId, {
    required String name,
    required int days,
    required int priceCents,
    String? vatRateId,
  });

  /// Owner-only: partial update. Deactivate = `updatePackage(active: false)`
  /// — packages are never deleted (bill lines reference the purchase).
  Future<Package> updatePackage(
    String packageId, {
    String? name,
    int? days,
    int? priceCents,
    bool? active,
    String? vatRateId,
  });

  /// Buys a package (RPC `buy_package`): raises the caller's cap for the
  /// current period and posts the price as a charge on their bill. Only a
  /// member whose over-consumption policy is 'package' may buy. Returns the
  /// quota-extension id.
  Future<String> buyPackage(String workspaceId, String packageId);

  /// Which online-payment providers this WORKSPACE can charge with
  /// (create-payment-order's config probe) — plus per-provider missing
  /// config fields for the owner diagnostics. An undeployed function maps
  /// to [PaymentGatewayConfig.notDeployed], never a throw.
  Future<PaymentGatewayConfig> fetchPaymentConfig(String workspaceId);

  /// Owner-only: the per-provider server-config status (configured flag,
  /// non-secret fields, which secret fields are set — never their values).
  Future<Map<PaymentProvider, PaymentProviderStatus>> fetchPaymentGatewayStatus(
    String workspaceId,
  );

  /// Owner-only: merge [config] into a provider's server credentials
  /// (blank fields keep existing values). Secrets go to the deny-all
  /// payment_credentials table via an owner-gated RPC.
  Future<void> setPaymentCredentials(
    String workspaceId,
    PaymentProvider provider,
    Map<String, String> config,
  );

  /// Owner-only: remove a provider's server credentials entirely.
  Future<void> clearPaymentProvider(String workspaceId, PaymentProvider provider);

  /// Can this workspace SEND an e-invoice, and what does it still need
  /// (0073)? An undeployed function maps to
  /// [EInvoiceGatewayConfig.notConfigured], never a throw — the app hides
  /// the affordance rather than offering a button that cannot work.
  Future<EInvoiceGatewayConfig> fetchEInvoiceGateway(String workspaceId);

  /// Posts an issued invoice's document to one of the workspace's
  /// e-invoicing channels (Edge Function `send-e-invoice`): the
  /// government platform, or the customer's own delivery service (#568).
  /// The CLIENT builds the bytes with the same builder the download uses;
  /// the function holds the credential and records the attempt.
  Future<EInvoiceSubmission> sendEInvoice({
    required String workspaceId,
    required String invoiceId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
    String environment = 'prod',
    String destination = 'government',
  });

  /// invoiceId → its LATEST transmission (0071); invoices never sent are
  /// absent. Admin-readable.
  Future<Map<String, InvoiceTransmission>> fetchInvoiceTransmissions(
    String workspaceId,
  );

  /// Owner-only: merge the platform credentials (blank fields keep their
  /// stored value, so an endpoint changes without re-typing a token).
  Future<void> setEInvoiceCredentials(
    String workspaceId,
    Map<String, String> config,
  );

  /// Owner-only: forget the platform entirely.
  Future<void> clearEInvoiceCredentials(String workspaceId);

  /// Owner-only: the non-secret fields as stored plus the NAMES of the
  /// secrets that are set — never a secret's value.
  Future<EInvoiceProviderStatus> fetchEInvoiceStatus(String workspaceId);

  /// Starts an online payment with [provider] for [amountCents] of the
  /// member's bill (docs/design/payments-integration.md). Returns the
  /// provider's approval URL + order id, or a not-configured result naming
  /// the missing server env vars. Throws [PaymentGatewayException] on
  /// provider/auth errors so traces carry the server detail.
  Future<PaymentOrderStart> createPaymentOrder({
    required PaymentProvider provider,
    required String workspaceId,
    required String memberId,
    required int amountCents,
    required String currencyCode,
    required String period,
  });
}
