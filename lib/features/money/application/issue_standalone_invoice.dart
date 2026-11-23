// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4165 (A2) -- issuing a standalone invoice whose answer may never come back.
//
// The server commits and then answers; a lost connection or an answer that
// does not decode leaves the commit UNKNOWN, not refused. The attempt -- the
// workspace, the draft, the CONFIRMED revision and the request id, captured
// when the person confirmed -- is kept, and the only thing offered is to
// LOOK: the receipt of THAT request in the attempt's own workspace. Looking
// never writes; a change of the selected workspace or account since does not
// move it. The request id makes a resend safe too: the server answers the
// invoice of the first attempt, never a second one.
import '../../../core/data/dk_code.dart';
import '../../../core/data/server_error.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/command_receipt.dart';
import '../domain/invoice_queries.dart';
import '../domain/standalone_invoice.dart';
import 'command_failure.dart';

/// What the person confirmed. Immutable, so a look concerns this attempt only.
final class StandaloneIssueAttempt {
  const StandaloneIssueAttempt({
    required this.workspaceId,
    required this.draftId,
    required this.revision,
    required this.requestId,
  });

  final String workspaceId;
  final String draftId;
  final int revision;

  /// Drawn once when the draft becomes an attempted command.
  final String requestId;
}

sealed class StandaloneIssueOutcome {
  const StandaloneIssueOutcome(this.attempt);
  final StandaloneIssueAttempt attempt;
}

/// The invoice exists.
final class StandaloneIssuedOutcome extends StandaloneIssueOutcome {
  const StandaloneIssuedOutcome(super.attempt, this.invoiceId, {this.number = ''});
  final String invoiceId;

  /// The invoice number, when the answer carried it (a look finds the id only).
  final String number;
}

/// The server said no, with its own words: nothing was issued.
final class StandaloneIssueRefused extends StandaloneIssueOutcome {
  const StandaloneIssueRefused(super.attempt, this.error);
  final Object error;
}

/// The request left and its answer did not come back usable: whether the
/// invoice exists is not known.
final class StandaloneIssueUnknown extends StandaloneIssueOutcome {
  const StandaloneIssueUnknown(super.attempt, this.cause);
  final Object cause;
}

class StandaloneIssuance {
  const StandaloneIssuance(this._commands, this._queries);

  final StandaloneInvoiceCommands _commands;
  final InvoiceQueries _queries;

  /// Sends [attempt] once. A decoding or transport error is
  /// [StandaloneIssueUnknown], never a reason to try again by itself.
  Future<StandaloneIssueOutcome> issue(StandaloneIssueAttempt attempt) async {
    try {
      final done = await _commands.issue(
        workspaceId: attempt.workspaceId,
        draftId: attempt.draftId,
        revision: attempt.revision,
        requestId: attempt.requestId,
      );
      return StandaloneIssuedOutcome(attempt, done.invoiceId, number: done.number);
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'standalone invoice issue failed',
          error: e, stackTrace: st);
      return isDefiniteRefusal(e)
          ? StandaloneIssueRefused(attempt, e)
          : StandaloneIssueUnknown(attempt, e);
    }
  }

  /// Reads THAT request's receipt in the attempt's own workspace: the invoice
  /// when it exists, otherwise the same unknown it started from. A missing
  /// receipt is only "not observed"; a failing read is unknown too.
  Future<StandaloneIssueOutcome> look(StandaloneIssueUnknown unknown) async {
    final attempt = unknown.attempt;
    try {
      final receipt = await _queries.invoiceCommandOutcome(
        workspaceId: attempt.workspaceId,
        requestId: attempt.requestId,
      );
      return switch (receipt.state) {
        CommandReceiptState.applied =>
          StandaloneIssuedOutcome(attempt, receipt.invoiceId!),
        _ => unknown,
      };
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'standalone receipt unreadable',
          error: e, stackTrace: st);
      return StandaloneIssueUnknown(attempt, e);
    }
  }
}

/// The facts the server named when it refused a draft (`DKI01`, its detail:
/// stable keys such as `line_1_quantity`, `due_on`, `draft_stale`); empty for
/// any other failure.
List<String> standaloneRefusalKeys(Object error) {
  final details = serverErrorDetails(error);
  return serverErrorCode(error) == DkCode.dki01 && details != null && details.isNotEmpty
      ? details.split(',')
      : const [];
}

/// Traces a failed standalone command (the screen's own words are its refusal).
void traceStandaloneFailure(String what, Object error, StackTrace stack) =>
    TraceLogger.instance.error('money', what, error: error, stackTrace: stack);
