// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2585 — issuing an invoice whose answer may never come back.
//
// `request_invoice_issue` commits on the server and then answers. A lost
// connection or an answer that does not decode leaves the commit UNKNOWN,
// not refused: the invoice may exist. The old path told the person a
// generic failure, closed the form and left them to issue again.
//
// This command makes the honest outcomes reachable. APPLIED (the id), HELD
// (a validator decides) and REFUSED (the server said no, in words) are
// answers the server gave. UNKNOWN is everything else, and for it the
// attempt — the workspace, member, period and the whole draft captured when
// the person confirmed — is kept, and the only thing offered is to LOOK:
// the invoice archive of the attempt's own workspace is read for the
// document the attempt would have made. Looking never writes; the server's
// one-active-invoice-per-member-and-month rule (0067) is what makes the
// archive an answer. A change of the selected workspace or account since
// does not move the look: it reads the captured workspace, or nothing.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../../core/data/app_failure_from.dart';
import '../../../core/failure/app_failure.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/billing_rules.dart';
import '../domain/command_receipt.dart';
import '../domain/invoice_action_commands.dart';
import '../domain/invoice_commands.dart';
import '../domain/invoice_queries.dart';

/// What the person confirmed: the context it was made in and the draft.
/// Immutable, so a look can only ever concern this attempt.
final class InvoiceIssueAttempt {
  const InvoiceIssueAttempt({
    required this.workspaceId,
    required this.memberId,
    required this.period,
    this.replacesId,
    this.detailed = false,
    this.kind = InvoiceKind.full,
    this.buyerReference = '',
    this.purchaseOrder = '',
    this.correctionReason = '',
    this.requestId,
    this.direct = false,
  });

  /// #2585 C2 — the attempt's identity, drawn once when the draft becomes
  /// an attempted command. A NEW invoice carrying one is sent under it and
  /// looked up by it; a replacement (or an attempt without one) keeps the
  /// archive look of before, which is a bounded safety net, not an identity.
  final String? requestId;

  /// The wizard / sweep issue: straight to `create_invoice`, no validation
  /// policy (as before), under the same receipt.
  final bool direct;

  bool get hasReceipt => requestId != null;

  final String workspaceId;
  final String memberId;
  final String period;
  final String? replacesId;
  final bool detailed;
  final InvoiceKind kind;
  final String buyerReference;
  final String purchaseOrder;
  final String correctionReason;
}

/// The validators declined (or let expire) the held request: nothing was
/// issued. A receipt look answers it as a refusal whose cause this is.
final class InvoiceIssueDeclined implements TypedRefusal {
  const InvoiceIssueDeclined(this.eventId);
  final String eventId;

  @override
  String toString() => 'InvoiceIssueDeclined($eventId)';
}

/// Whether [refusal] is a validator's decline (never retried: a new request
/// would ask the same question again).
bool isDeclined(Refusal refusal) => refusal.cause is InvoiceIssueDeclined;

/// Issuing an invoice exactly once, and looking for it afterwards.
class InvoiceIssuance {
  const InvoiceIssuance(this._commands, this._queries, [this._actions]);

  final InvoiceCommands _commands;
  final InvoiceActionCommands? _actions;
  final InvoiceQueries _queries;

  /// Sends [attempt] ONCE: the invoice id, held for a validation, refused in
  /// the server's words, or not reached. Never resends: a decoding or
  /// transport error is [CommandUnreached], not a reason to try again.
  Future<CommandOutcome<String>> issue(InvoiceIssueAttempt attempt) =>
      runCommand(
        () => attempt.hasReceipt
            ? _sendReceipted(attempt)
            : _commands.createInvoice(
                workspaceId: attempt.workspaceId,
                memberId: attempt.memberId,
                period: attempt.period,
                replacesId: attempt.replacesId,
                detailed: attempt.detailed,
                kind: attempt.kind,
                buyerReference: attempt.buyerReference,
                purchaseOrder: attempt.purchaseOrder,
                correctionReason: attempt.correctionReason,
              ),
        what: 'invoice issue failed',
      );

  Future<String> _sendReceipted(InvoiceIssueAttempt attempt) {
    final command = InvoiceIssueCommand(
      workspaceId: attempt.workspaceId,
      memberId: attempt.memberId,
      period: attempt.period,
      requestId: attempt.requestId!,
      detailed: attempt.detailed,
      kind: attempt.kind,
      buyerReference: attempt.buyerReference,
      purchaseOrder: attempt.purchaseOrder,
      correctionReason: attempt.correctionReason,
      replacesId: attempt.replacesId,
    );
    if (attempt.replacesId != null) return _actions!.replaceInvoiceOnce(command);
    return attempt.direct
        ? _actions!.createInvoiceOnce(command)
        : _commands.issueInvoiceWithReceipt(command);
  }

  /// Reads the archive of [attempt]'s own workspace for the invoice the
  /// attempt made: done with the original id when it exists, otherwise the
  /// same [unknown] it started from. A read that fails is not reached too; it
  /// is never read as "not issued".
  Future<CommandOutcome<String>> look(
    InvoiceIssueAttempt attempt,
    CommandUnreached<String> unknown,
  ) async {
    if (attempt.hasReceipt) return _lookReceipt(attempt, unknown);
    try {
      final invoices = await _queries.fetchInvoices(attempt.workspaceId);
      for (final invoice in invoices) {
        if (_isTheAttempt(invoice, attempt)) return CommandDone(invoice.id);
      }
      return unknown;
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'invoice issue outcome unknown', error: e, stackTrace: st);
      return CommandUnreached(appFailureFrom(e));
    }
  }

  /// Reads THAT request's receipt on the attempt's own workspace. Applied
  /// and pending carry the original ids; a missing receipt is only "not
  /// observed" — the attempt stays unknown, retained, never resent.
  Future<CommandOutcome<String>> _lookReceipt(
    InvoiceIssueAttempt attempt,
    CommandUnreached<String> unknown,
  ) async {
    try {
      final receipt = await _queries.invoiceCommandOutcome(
        workspaceId: attempt.workspaceId,
        requestId: attempt.requestId!,
      );
      return switch (receipt.state) {
        CommandReceiptState.applied => CommandDone(receipt.invoiceId!),
        CommandReceiptState.pending => CommandHeld(receipt.eventId!),
        CommandReceiptState.refused => CommandRefused(
          Refusal(cause: InvoiceIssueDeclined(receipt.eventId!)),
        ),
        CommandReceiptState.notObserved => unknown,
      };
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'invoice receipt unreadable', error: e, stackTrace: st);
      return CommandUnreached(appFailureFrom(e));
    }
  }

  bool _isTheAttempt(Invoice invoice, InvoiceIssueAttempt attempt) =>
      invoice.workspaceId == attempt.workspaceId &&
      invoice.memberId == attempt.memberId &&
      invoice.period == attempt.period &&
      !invoice.isVoided &&
      invoice.kind == attempt.kind &&
      invoice.replacesInvoiceId == attempt.replacesId;
}
