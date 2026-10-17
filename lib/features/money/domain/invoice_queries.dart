// SPDX-License-Identifier: AGPL-3.0-or-later
import 'billing_rules.dart';
import 'command_receipt.dart';
import 'invoice.dart';
import 'reminder_evidence.dart';
import 'vat_tax_point.dart';

/// #2591 C1 — the read side of the invoice archive and the invoice
/// lifecycle: the register, the preview, the readiness check, the matches,
/// the instalments, the reminders. Nothing here writes, so a consumer that
/// only reads invoices needs no other member of the money boundary.
abstract interface class InvoiceQueries {
  /// The invoice archive (0060): the member's own invoices — admins see
  /// everyone's (RLS decides).
  Future<List<Invoice>> fetchInvoices(String workspaceId);

  /// #2585 C2 — the receipt of the attempt named [requestId] (RPC
  /// `financial_command_outcome_v1`): only the caller's own attempt in
  /// [workspaceId] can be found. Reads, never writes.
  Future<CommandReceipt> invoiceCommandOutcome({
    required String workspaceId,
    required String requestId,
  });

  /// Every payment already consumed by a match (#506, 0101) — the
  /// candidates list must not offer them again.
  Future<Set<String>> fetchConsumedPaymentIds(String workspaceId);

  /// What [createInvoice] would issue for [period], without issuing
  /// (RPC `preview_invoice`, 0062).
  Future<({List<InvoiceLine> lines, int totalCents})> previewInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
  });

  /// What stops [createInvoice] from issuing for [period] (RPC
  /// `invoice_issue_readiness`, 0365): the essential details of a legal
  /// invoice that are still missing, as stable keys; empty when nothing
  /// is. A dry run of the very same issue, so the two cannot disagree.
  Future<List<String>> invoiceIssueReadiness({
    required String workspaceId,
    required String memberId,
    required String period,
    InvoiceKind kind = InvoiceKind.full,
    String? replacesId,
    String correctionReason = '',
  });

  /// invoiceId → reminder count + last reminder instant (0066).
  /// #1922 (0334) — the reminders of one invoice and what is known about
  /// their delivery (RPC `invoice_reminder_evidence`): issuers and the
  /// invoice's own member only.
  Future<List<ReminderEvidence>> fetchReminderEvidence(String invoiceId);

  Future<Map<String, ({int count, DateTime last})>> fetchInvoiceReminders(
    String workspaceId,
  );

  /// invoiceId → its match (0067). status 'pending' while a validation
  /// quorum decides; a reject deletes the row (the invoice reopens).
  Future<Map<String, InvoiceMatch>> fetchInvoiceMatches(String workspaceId);

  /// #2355 — invoiceId → every payment matched to it, one by one
  /// (`invoice_match_payments`, 0101): an invoice paid in instalments
  /// falls into as many VAT periods as it had payments on a receipts
  /// basis. Empty for an invoice whose match records no junction row.
  Future<Map<String, List<TaxPointPayment>>> fetchInvoiceInstalments(
    String workspaceId,
  );
}
