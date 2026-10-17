// SPDX-License-Identifier: AGPL-3.0-or-later
import 'billing_rules.dart';
import 'commercial_terms_repository.dart';
import 'dunning.dart';
import 'einvoice_gateway.dart';
import 'expense_repository.dart';
import 'invoice_commands.dart';
import 'invoice_queries.dart';
import 'member_account_queries.dart';
import 'number_sequence.dart';
import 'payment_intent.dart';
import 'payment_method.dart';
import 'payment_provider.dart';
import 'report_template_repository.dart';
import 'tax_reporting_repository.dart';
import 'workspace_status.dart';

export 'command_receipt.dart';

/// Compatibility facade (#2591 C4): it implements every narrow money port
/// (invoice and account reads, report templates, invoice commands, tax
/// reporting, commercial terms, expenses) and still declares what has not
/// moved yet. It gets NO new methods — new product code depends on the
/// narrow port it needs, not on this.
///
/// Money boundary (spec §7). Payments are only *recorded* — the pending
/// event created by [recordPayment] must be confirmed by the other side
/// before a ledger credit exists.
abstract class MoneyRepository implements
        InvoiceQueries,
        MemberAccountQueries,
        ReportTemplateRepository,
        InvoiceCommands,
        TaxReportingRepository,
        CommercialTermsRepository,
        ExpenseRepository {
  /// The workspace's dunning policy (#472, 0093); defaults when unset.
  Future<DunningRules> fetchDunningRules(String workspaceId);

  /// #802 — when the two automatic invoice runs happen.
  Future<BillingRules> fetchBillingRules(String workspaceId);

  /// #934 — the workspace's status over [from]..[to] (YYYY-MM), admins
  /// and owners only (RPC `workspace_status`).
  Future<WorkspaceStatus> fetchWorkspaceStatus(
      String workspaceId, String from, String to);

  /// #934 — the remembered repartition rule (`billing_rules.repartition`).
  Future<RepartitionRule> fetchRepartitionRule(String workspaceId);

  /// #934 — remember the rule the wizard was adjusted to.
  Future<void> setRepartitionRule(String workspaceId, RepartitionRule rule);

  /// Owner/admin only, server-enforced.
  Future<void> setBillingRules(String workspaceId, BillingRules rules);

  /// Runs both invoice runs for this workspace NOW instead of waiting for
  /// the nightly clock, and answers how many documents it raised.
  Future<int> sweepBillingInvoices(String workspaceId);

  /// #726 — apply the dunning rules now (idempotent: the rules decide).
  /// Returns how many reminders were recorded. Admins only.
  Future<int> sweepPaymentReminders(String workspaceId);

  /// Owner-only: persist the dunning policy.
  Future<void> setDunningRules(String workspaceId, DunningRules rules);

  /// #925 — every number series of the workspace (table
  /// `number_sequences`, 0164), one per journal, seeded lazily.
  Future<List<NumberSequence>> fetchNumberSequences(String workspaceId);

  /// #956 — 'verified' | 'altered' | 'unverifiable' (RPC
  /// `verify_invoice_signature`): the fingerprint recomputed from the
  /// stored columns.
  Future<String> verifyInvoiceSignature(String invoiceId);

  /// #925 — the owner sets a series' format; the counter may only be
  /// raised (RPC `set_number_sequence`).
  Future<void> setNumberSequence(
    String workspaceId,
    NumberSequence sequence, {
    int? raiseNextValueTo,
  });

  /// #925 — what the next number of [journal] would be, without taking
  /// it (RPC `preview_document_number`).
  Future<String> previewDocumentNumber(String workspaceId, String journal);

  /// #833 — "I left before the booking ended; bill the time I was
  /// actually here." Only the member concerned may ask, and never
  /// decides it themselves. Returns the event id.
  Future<String> requestUsageCorrection(String recordId, {String reason});

  /// #833 — an admin removing a record; the member concerned validates
  /// it when a rule says so. Returns the event id.
  Future<String> requestUsageRecordDelete(String recordId, {String reason});

  /// #1913 (0331) — invoiceId → the reason of its ACTIVE dunning hold
  /// (`dispute`, `identity_error`, `insolvency`, `other`). A held invoice
  /// is not reminded, by hand or by the sweep.
  Future<Map<String, String>> fetchDunningHolds(String workspaceId);

  /// #1913 — places a hold (RPC `place_dunning_hold`); only whoever
  /// issues the invoices of the space may.
  Future<void> placeDunningHold(
    String invoiceId, {
    required String reason,
    String note = '',
  });

  /// #1913 — releases the active hold (RPC `release_dunning_hold`).
  Future<void> releaseDunningHold(String invoiceId);

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
    String format = '',
    String receiverScheme = '',
    String receiverId = '',
  });

  /// #2358 — asks the channel what became of an earlier transmission and
  /// stores its receipt (a Peppol evidence, the PA lifecycle, the SdI
  /// notification, the KSeF number, the ANAF state) on that row.
  Future<EInvoiceSubmission> requestEInvoiceReceipt({
    required String workspaceId,
    required String transmissionId,
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
  ///
  /// [requestId] (#2014 B) names the attempt: a retry with the same id is
  /// answered from the intent it already opened, never a second order.
  /// A request that was already paid answers [PaymentOrderStart.alreadyPaid].
  Future<PaymentOrderStart> createPaymentOrder({
    required PaymentProvider provider,
    required String workspaceId,
    required String memberId,
    required int amountCents,
    required String currencyCode,
    required String period,
    String? requestId,
  });
}
