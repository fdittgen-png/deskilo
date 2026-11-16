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
//   * withdraw: an online payment's claim, or (#4140) takes back a declared
//     one the business has not decided;
//   * enter: the business of a selection, before its payment flow runs.
// A refusal of the server is thrown as [ClaimRefused], nothing recorded.
import '../domain/finance_overview.dart';
import '../domain/finance_selection.dart';
import '../domain/member_account_commands.dart';
import '../domain/payment_claims.dart';

/// Enters [workspaceId] as Open does and answers my member's id there; null
/// when it cannot be entered or the account changed meanwhile.
typedef FinanceWorkspaceEntry = Future<String?> Function(String workspaceId);

class FinanceSelectionCommands {
  FinanceSelectionCommands({required this.enter, required this.commands});

  final FinanceWorkspaceEntry enter;

  /// The account commands of the business entered last.
  final MemberAccountCommands Function() commands;

  /// Declares [selection] paid, one declaration per month, telling
  /// [onRecorded] each month recorded. False when its business could not be
  /// entered (nothing recorded).
  Future<bool> declare(
    FinanceSelection selection, {
    void Function(SelectionMonth month)? onRecorded,
  }) async {
    final workspaceId = selection.workspaceId!;
    final memberId = await enter(workspaceId);
    if (memberId == null) return false;
    for (final month in selection.months) {
      await commands().declareInvoicesPaid(
        workspaceId: workspaceId,
        memberId: memberId,
        claim: InvoiceClaim(
          period: month.period,
          amountCents: month.cents,
          invoiceIds: [for (final i in month.invoices) i.id],
        ),
      );
      onRecorded?.call(month);
    }
    return true;
  }

  /// Withdraws the online payment holding [invoice], or takes back the
  /// declared one. False when there is none or its business could not be
  /// entered.
  Future<bool> withdraw(FinanceInvoice invoice) async {
    final paymentId = invoice.claimPaymentId;
    final eventId = invoice.claimEventId;
    if (paymentId == null && eventId == null) return false;
    if (await enter(invoice.workspaceId) == null) return false;
    if (paymentId != null) {
      await commands().withdrawPaymentClaim(
        workspaceId: invoice.workspaceId,
        paymentId: paymentId,
      );
    } else {
      await commands().withdrawPaymentDeclaration(
        workspaceId: invoice.workspaceId,
        eventId: eventId!,
      );
    }
    return true;
  }

  /// Enters the business of [selection] before its payment flow runs (the
  /// flow pays in the business entered).
  Future<bool> enterFor(FinanceSelection selection) async =>
      await enter(selection.workspaceId!) != null;
}
