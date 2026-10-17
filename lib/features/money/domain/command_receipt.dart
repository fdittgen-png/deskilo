// SPDX-License-Identifier: AGPL-3.0-or-later
import 'billing_rules.dart';

/// #2585 C2 — what the server recorded for ONE financial command attempt,
/// found by the request id the attempt carried (RPC
/// `financial_command_outcome_v1`, 0462).
///
/// [notObserved] is a statement about the receipt, not about the command: a
/// request still in flight may yet commit, so it never proves the attempt
/// failed and is never a reason to send a new one.
enum CommandReceiptState { notObserved, applied, pending, refused }

/// The receipt of one attempt. [invoiceId] is set when [state] is
/// [CommandReceiptState.applied]; [eventId] when it is pending or refused.
final class CommandReceipt {
  const CommandReceipt(this.state, {this.invoiceId, this.eventId});

  final CommandReceiptState state;
  final String? invoiceId;
  final String? eventId;
}

/// #2585 C2 — a NEW invoice to issue under its attempt's [requestId]. One
/// value, so the port keeps one parameter and the identity can never be
/// dropped between the draft and the server.
final class InvoiceIssueCommand {
  const InvoiceIssueCommand({
    required this.workspaceId,
    required this.memberId,
    required this.period,
    required this.requestId,
    this.detailed = false,
    this.kind = InvoiceKind.full,
    this.buyerReference = '',
    this.purchaseOrder = '',
    this.correctionReason = '',
  });

  final String workspaceId;
  final String memberId;
  final String period;
  final String requestId;
  final bool detailed;
  final InvoiceKind kind;
  final String buyerReference;
  final String purchaseOrder;

  /// Carried with the draft; the server's new-invoice path does not take it
  /// (as before, only a replacement sends it).
  final String correctionReason;
}
