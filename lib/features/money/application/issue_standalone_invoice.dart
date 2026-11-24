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
import '../../../core/codes/dk_code.dart';
import '../../../core/data/app_failure_from.dart';
import '../../../core/data/server_error.dart';
import '../../../core/failure/app_failure.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/command_receipt.dart';
import '../domain/invoice_queries.dart';
import '../domain/standalone_invoice.dart';

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

class StandaloneIssuance {
  const StandaloneIssuance(this._commands, this._queries);

  final StandaloneInvoiceCommands _commands;
  final InvoiceQueries _queries;

  /// Sends [attempt] once: the invoice, a refusal in the server's words, or
  /// not reached (a decoding or transport error), which is never a reason to
  /// try again by itself.
  Future<CommandOutcome<StandaloneIssued>> issue(
    StandaloneIssueAttempt attempt,
  ) => runCommand(
    () => _commands.issue(
      workspaceId: attempt.workspaceId,
      draftId: attempt.draftId,
      revision: attempt.revision,
      requestId: attempt.requestId,
    ),
    what: 'standalone invoice issue failed',
  );

  /// Reads THAT request's receipt in [attempt]'s own workspace: the invoice
  /// when it exists, otherwise the same [unknown] it started from. A missing
  /// receipt is only "not observed"; a failing read is not reached too.
  Future<CommandOutcome<StandaloneIssued>> look(
    StandaloneIssueAttempt attempt,
    CommandUnreached<StandaloneIssued> unknown,
  ) async {
    try {
      final receipt = await _queries.invoiceCommandOutcome(
        workspaceId: attempt.workspaceId,
        requestId: attempt.requestId,
      );
      return switch (receipt.state) {
        CommandReceiptState.applied => CommandDone(
          StandaloneIssued(
            invoiceId: receipt.invoiceId!,
            number: '',
            replayed: true,
          ),
        ),
        _ => unknown,
      };
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'standalone receipt unreadable',
          error: e, stackTrace: st);
      return CommandUnreached(appFailureFrom(e));
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
