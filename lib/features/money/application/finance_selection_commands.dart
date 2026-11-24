// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (1b) — what My finances does with a selection and with a payment
// being processed, without a screen: each command first enters the business
// the invoices live in (as Open does: its own host, my member there), then
// writes there. The dialogs that confirm them stay in the presentation.
//   * declare: one declaration per month, each naming its invoices; each
//     month recorded is told to the caller, which takes it out of its
//     selection (the selection is the page's, never kept beyond it), so a
//     refusal of a later month keeps only what is still to declare;
//   * declare, for invoices without a month (#4165): ONE declaration of the
//     whole selection, under a request id that survives a lost answer;
//   * withdraw: an online payment's claim, or (#4140) takes back a declared
//     one the business has not decided;
//   * enter: the business of a selection, before its payment flow runs.
// A refusal of the server is thrown as [ClaimRefused], nothing recorded.
import '../../../core/backend/operation_context.dart' show WorkspaceTarget;
import '../domain/finance_overview.dart';
import '../domain/finance_selection.dart';
import '../domain/member_account_commands.dart';
import '../domain/payment_claims.dart';
import '../domain/payment_gateway_repository.dart';

/// Captures this verified workspace's member and command clients. The
/// selection of another workspace cannot change any of them.
typedef FinanceWorkspaceEntry = Future<FinanceCommandTarget?> Function(WorkspaceTarget target);

class FinanceCommandTarget {
  const FinanceCommandTarget({required this.target, required this.memberId,
    required this.currency, required this.commands, required this.gateway,
    required this.isCurrent, required this.release, required this.open,
    this.businessName = '', this.canAdminister = false});
  final WorkspaceTarget target;
  final String memberId, currency;

  /// The business these commands are for, and whether I administer it there
  /// (#4218): what a payment's diagnostics say and offer, never the selected
  /// business's.
  final String businessName;
  final bool canAdminister;
  final MemberAccountCommands commands;
  final PaymentGatewayRepository gateway;
  final bool Function() isCurrent;
  final void Function() release;
  final Future<bool> Function() open;
}

class FinanceSelectionCommands {
  FinanceSelectionCommands({required this.enter});
  final FinanceWorkspaceEntry enter;

  Future<FinanceCommandTarget?> capture(FinanceSelection selection) async {
    final target = selection.invoices.firstOrNull?.target;
    if (target == null || selection.invoices.any((i) => i.target != target)) return null;
    final captured = await enter(target);
    // #4165 — invoices without a month are paid by their financial subject:
    // the one this account acts as there. Another subject's are not paid
    // through this entry (a billing grant has its own, later); nothing is
    // sent for a debtor the account is not.
    if (captured != null && selection.isStandalone && selection.subjectId != captured.memberId) {
      captured.release();
      return null;
    }
    return captured;
  }

  Future<bool> declare(FinanceSelection selection, {
    void Function(SelectionMonth month)? onRecorded,
  }) async {
    final captured = await capture(selection);
    if (captured == null) return false;
    try {
      if (selection.isStandalone) {
        if (!captured.isCurrent()) return false;
        await captured.commands.declareInvoicesPaid(
          workspaceId: captured.target.workspaceId, memberId: captured.memberId,
          claim: InvoiceClaim.standalone(amountCents: selection.cents,
            invoiceIds: [for (final i in selection.standaloneInvoices) i.id]),
        );
        onRecorded?.call((period: '', invoices: selection.invoices, cents: selection.cents));
        return true;
      }
      for (final month in selection.months) {
        if (!captured.isCurrent()) return false;
        await captured.commands.declareInvoicesPaid(
          workspaceId: captured.target.workspaceId, memberId: captured.memberId,
          claim: InvoiceClaim(period: month.period, amountCents: month.cents,
            invoiceIds: [for (final i in month.invoices) i.id]),
        );
        onRecorded?.call(month);
      }
      return true;
    } finally {
      captured.release();
    }
  }

  Future<bool> withdraw(FinanceInvoice invoice) async {
    final paymentId = invoice.claimPaymentId;
    final eventId = invoice.claimEventId;
    final target = invoice.target;
    if (target == null || (paymentId == null && eventId == null)) return false;
    final captured = await enter(target);
    if (captured == null) return false;
    try {
      if (!captured.isCurrent()) return false;
      if (paymentId != null) {
        await captured.commands.withdrawPaymentClaim(
          workspaceId: target.workspaceId, paymentId: paymentId);
      } else {
        await captured.commands.withdrawPaymentDeclaration(
          workspaceId: target.workspaceId, eventId: eventId!);
      }
      return true;
    } finally {
      captured.release();
    }
  }
}
