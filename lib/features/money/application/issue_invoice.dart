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
import '../../../core/trace/trace_logger.dart';
import '../../../core/validation/pending_validation.dart';
import '../domain/billing_rules.dart';
import '../domain/command_receipt.dart';
import '../domain/invoice.dart';
import '../domain/invoice_action_commands.dart';
import '../domain/invoice_commands.dart';
import '../domain/invoice_queries.dart';
import 'command_failure.dart';

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

  bool get hasReceipt => requestId != null && replacesId == null;

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

/// How an issue attempt ended, or did not.
sealed class InvoiceIssueOutcome {
  const InvoiceIssueOutcome(this.attempt);
  final InvoiceIssueAttempt attempt;
}

/// The invoice exists; [invoiceId] is the original one.
final class InvoiceIssued extends InvoiceIssueOutcome {
  const InvoiceIssued(super.attempt, this.invoiceId);
  final String invoiceId;
}

/// A validation policy holds the request; nothing was issued yet.
final class InvoiceIssueHeld extends InvoiceIssueOutcome {
  const InvoiceIssueHeld(super.attempt, this.eventId);
  final String eventId;
}

/// The server answered with a refusal: nothing was issued.
final class InvoiceIssueRefused extends InvoiceIssueOutcome {
  const InvoiceIssueRefused(super.attempt, this.error);
  final Object error;
}

/// The validators declined (or let expire) the held request: nothing was
/// issued. Carried as the [InvoiceIssueRefused] error of a receipt look.
final class InvoiceIssueDeclined implements Exception {
  const InvoiceIssueDeclined(this.eventId);
  final String eventId;

  @override
  String toString() => 'InvoiceIssueDeclined($eventId)';
}

/// The request left and its answer did not come back usable. The attempt
/// is retained; whether the invoice exists is not known.
final class InvoiceIssueUnknown extends InvoiceIssueOutcome {
  const InvoiceIssueUnknown(super.attempt, this.cause);
  final Object cause;
}

/// Issuing an invoice exactly once, and looking for it afterwards.
class InvoiceIssuance {
  const InvoiceIssuance(this._commands, this._queries, [this._actions]);

  final InvoiceCommands _commands;
  final InvoiceActionCommands? _actions;
  final InvoiceQueries _queries;

  /// Sends [attempt] ONCE. Never resends: a decoding or transport error is
  /// [InvoiceIssueUnknown], not a reason to try again.
  Future<InvoiceIssueOutcome> issue(InvoiceIssueAttempt attempt) async {
    try {
      final id = attempt.hasReceipt
          ? await _sendReceipted(attempt)
          : await _commands.createInvoice(
        workspaceId: attempt.workspaceId,
        memberId: attempt.memberId,
        period: attempt.period,
        replacesId: attempt.replacesId,
        detailed: attempt.detailed,
        kind: attempt.kind,
        buyerReference: attempt.buyerReference,
        purchaseOrder: attempt.purchaseOrder,
        correctionReason: attempt.correctionReason,
      );
      return InvoiceIssued(attempt, id);
    } on PendingValidationException catch (e, st) {
      TraceLogger.instance.error('money', 'invoice issue held', error: e, stackTrace: st);
      return InvoiceIssueHeld(attempt, e.eventId);
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'invoice issue failed', error: e, stackTrace: st);
      return isDefiniteRefusal(e)
          ? InvoiceIssueRefused(attempt, e)
          : InvoiceIssueUnknown(attempt, e);
    }
  }

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
    );
    return attempt.direct
        ? _actions!.createInvoiceOnce(command)
        : _commands.issueInvoiceWithReceipt(command);
  }

  /// Reads the archive of the attempt's own workspace for the invoice the
  /// attempt made: [InvoiceIssued] with the original id when it exists,
  /// otherwise the same [InvoiceIssueUnknown] it started from. A read that
  /// fails is unknown too; it is never read as "not issued".
  Future<InvoiceIssueOutcome> look(InvoiceIssueUnknown unknown) async {
    final attempt = unknown.attempt;
    if (attempt.hasReceipt) return _lookReceipt(unknown);
    try {
      final invoices = await _queries.fetchInvoices(attempt.workspaceId);
      for (final invoice in invoices) {
        if (_isTheAttempt(invoice, attempt)) {
          return InvoiceIssued(attempt, invoice.id);
        }
      }
      return unknown;
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'invoice issue outcome unknown', error: e, stackTrace: st);
      return InvoiceIssueUnknown(attempt, e);
    }
  }

  /// Reads THAT request's receipt on the attempt's own workspace. Applied
  /// and pending carry the original ids; a missing receipt is only "not
  /// observed" — the attempt stays unknown, retained, never resent.
  Future<InvoiceIssueOutcome> _lookReceipt(InvoiceIssueUnknown unknown) async {
    final attempt = unknown.attempt;
    try {
      final receipt = await _queries.invoiceCommandOutcome(
        workspaceId: attempt.workspaceId,
        requestId: attempt.requestId!,
      );
      return switch (receipt.state) {
        CommandReceiptState.applied => InvoiceIssued(attempt, receipt.invoiceId!),
        CommandReceiptState.pending => InvoiceIssueHeld(attempt, receipt.eventId!),
        CommandReceiptState.refused =>
          InvoiceIssueRefused(attempt, InvoiceIssueDeclined(receipt.eventId!)),
        CommandReceiptState.notObserved => unknown,
      };
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'invoice receipt unreadable', error: e, stackTrace: st);
      return InvoiceIssueUnknown(attempt, e);
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
