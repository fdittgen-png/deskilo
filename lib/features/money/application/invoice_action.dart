// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2585 C2 — voiding an invoice or refunding a credit note whose answer may
// never come back.
//
// The attempt carries one request id, drawn when the person confirmed. It is
// sent ONCE under that id; a transport or decoding error is UNKNOWN, not a
// refusal, and the only thing offered is to LOOK: the receipt of THAT request
// is read from the attempt's own workspace (0463). A missing receipt is "not
// observed", which proves nothing, so the attempt stays unknown and retained.
// Nothing here ever sends the command a second time.
import '../../../core/trace/trace_logger.dart';
import '../../../core/validation/pending_validation.dart';
import '../domain/command_receipt.dart';
import '../domain/invoice_action_commands.dart';
import '../domain/invoice_queries.dart';
import 'command_failure.dart';

enum InvoiceActionKind { voidInvoice, refundCreditNote }

/// What the person confirmed. Immutable, so a look concerns only this act.
final class InvoiceActionAttempt {
  const InvoiceActionAttempt({
    required this.workspaceId,
    required this.invoiceId,
    required this.kind,
    required this.requestId,
    this.note = '',
  });

  final String workspaceId;
  final String invoiceId;
  final InvoiceActionKind kind;
  final String requestId;
  final String note;
}

sealed class InvoiceActionOutcome {
  const InvoiceActionOutcome(this.attempt);
  final InvoiceActionAttempt attempt;
}

/// The server applied it (or its receipt says so).
final class InvoiceActionDone extends InvoiceActionOutcome {
  const InvoiceActionDone(super.attempt);
}

/// A validation policy holds it; nothing changed yet.
final class InvoiceActionHeld extends InvoiceActionOutcome {
  const InvoiceActionHeld(super.attempt, this.eventId);
  final String eventId;
}

/// The server said no (in words), or the validators declined.
final class InvoiceActionRefused extends InvoiceActionOutcome {
  const InvoiceActionRefused(
    super.attempt,
    this.error, {
    this.declined = false,
  });
  final Object error;

  /// The held request was rejected or expired, as opposed to refused at once.
  final bool declined;
}

/// The answer did not come back usable; whether it applied is not known.
final class InvoiceActionUnknown extends InvoiceActionOutcome {
  const InvoiceActionUnknown(super.attempt, this.cause);
  final Object cause;
}

class InvoiceReceiptActions {
  const InvoiceReceiptActions(this._commands, this._queries);

  final InvoiceActionCommands _commands;
  final InvoiceQueries _queries;

  /// Sends [attempt] ONCE.
  Future<InvoiceActionOutcome> run(InvoiceActionAttempt attempt) async {
    try {
      switch (attempt.kind) {
        case InvoiceActionKind.voidInvoice:
          await _commands.voidInvoice(
            attempt.invoiceId,
            requestId: attempt.requestId,
            reason: attempt.note,
          );
        case InvoiceActionKind.refundCreditNote:
          await _commands.settleCreditInvoice(
            attempt.invoiceId,
            requestId: attempt.requestId,
            note: attempt.note,
          );
      }
      return InvoiceActionDone(attempt);
    } on PendingValidationException catch (e, st) {
      TraceLogger.instance.error(
        'money',
        'invoice action held',
        error: e,
        stackTrace: st,
      );
      return InvoiceActionHeld(attempt, e.eventId);
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'money',
        'invoice action failed',
        error: e,
        stackTrace: st,
      );
      return isDefiniteRefusal(e)
          ? InvoiceActionRefused(attempt, e)
          : InvoiceActionUnknown(attempt, e);
    }
  }

  /// Reads THAT request's receipt on the attempt's own workspace.
  Future<InvoiceActionOutcome> look(InvoiceActionUnknown unknown) async {
    final attempt = unknown.attempt;
    try {
      final receipt = await _queries.invoiceCommandOutcome(
        workspaceId: attempt.workspaceId,
        requestId: attempt.requestId,
      );
      return switch (receipt.state) {
        CommandReceiptState.applied => InvoiceActionDone(attempt),
        CommandReceiptState.pending => InvoiceActionHeld(
          attempt,
          receipt.eventId!,
        ),
        CommandReceiptState.refused => InvoiceActionRefused(
          attempt,
          StateError('declined ${receipt.eventId}'),
          declined: true,
        ),
        CommandReceiptState.notObserved => unknown,
      };
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'money',
        'invoice action receipt unreadable',
        error: e,
        stackTrace: st,
      );
      return InvoiceActionUnknown(attempt, e);
    }
  }
}
