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
import '../../../core/data/app_failure_from.dart';
import '../../../core/failure/app_failure.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/command_receipt.dart';
import '../domain/invoice_action_commands.dart';
import '../domain/invoice_queries.dart';

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

/// The validators declined (or let expire) the held act: nothing changed.
/// A receipt look answers it as a refusal whose cause this is.
final class InvoiceActionDeclined implements TypedRefusal {
  const InvoiceActionDeclined(this.eventId);
  final String eventId;

  @override
  String toString() => 'InvoiceActionDeclined($eventId)';
}

class InvoiceReceiptActions {
  const InvoiceReceiptActions(this._commands, this._queries);

  final InvoiceActionCommands _commands;
  final InvoiceQueries _queries;

  /// Sends [attempt] ONCE: done, held for a validation, refused in the
  /// server's words, or not reached (never a reason to send again).
  Future<CommandOutcome<void>> run(InvoiceActionAttempt attempt) => runCommand(
    () async {
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
    },
    what: 'invoice action failed',
  );

  /// Reads THAT request's receipt on [attempt]'s own workspace: applied,
  /// held, declined, or the same [unknown] when it is not observed.
  Future<CommandOutcome<void>> look(
    InvoiceActionAttempt attempt,
    CommandUnreached<void> unknown,
  ) async {
    try {
      final receipt = await _queries.invoiceCommandOutcome(
        workspaceId: attempt.workspaceId,
        requestId: attempt.requestId,
      );
      return switch (receipt.state) {
        CommandReceiptState.applied => const CommandDone<void>(null),
        CommandReceiptState.pending => CommandHeld(receipt.eventId!),
        CommandReceiptState.refused => CommandRefused(
          Refusal(cause: InvoiceActionDeclined(receipt.eventId!)),
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
      return CommandUnreached(appFailureFrom(e));
    }
  }
}
