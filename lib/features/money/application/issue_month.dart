// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-e -- "Invoice the month": the customers a person ticked, each
// issued ONCE under its own request id, and an honest report of what
// happened to every one. Nothing here knows a widget: the flow reads the
// report to draw its result page ("Issued", "Waits for a validation",
// "Not done" with a reason, "Could not be confirmed").
//
// The rules of issuing are the existing ones (`InvoiceIssuance`, the
// receipt-backed `create_invoice`): this only orders them for a batch.
// A customer whose answer was lost is never sent again: the same request id
// is looked up, so a retry can neither double an invoice nor call a
// committed one a failure.
import '../../../core/failure/app_failure.dart';
import '../../../core/ids/request_id.dart';
import 'issue_invoice.dart';

/// Where one customer stands while the month is issued.
enum MonthLineProgress { waiting, issuing, done }

/// One customer's attempt and what it answered: the attempt is kept, so a
/// lost answer is looked for under the same request and never resent.
typedef MonthIssueLine = ({
  InvoiceIssueAttempt attempt,
  CommandOutcome<String> outcome,
});

/// What happened to every ticked customer, in the order they were ticked.
final class MonthIssueReport {
  const MonthIssueReport(this.lines);

  /// One line per customer, by member id, in ticking order.
  final Map<String, MonthIssueLine> lines;

  Iterable<String> _of(bool Function(CommandOutcome<String>) test) => [
    for (final e in lines.entries)
      if (test(e.value.outcome)) e.key,
  ];

  /// The invoice exists.
  List<String> get issued => _of((o) => o is CommandDone).toList();

  /// A validation policy holds the request: nothing was issued yet.
  List<String> get held => _of((o) => o is CommandHeld).toList();

  /// The server said no, in words: retry may help once the cause is fixed.
  /// A request a validator declined is not one of these (see [declined]).
  List<String> get refused => _of(
    (o) => o is CommandRefused<String> && !isDeclined(o.refusal),
  ).toList();

  /// A validator declined the request: it is not retried, a new request would
  /// ask the same question again.
  List<String> get declined => _of(
    (o) => o is CommandRefused<String> && isDeclined(o.refusal),
  ).toList();

  /// The answer was lost: the invoice may exist; only looking again helps.
  List<String> get unknown => _of((o) => o is CommandUnreached).toList();

  /// What did not end in an invoice or a held request.
  List<String> get notDone => [...refused, ...declined, ...unknown];

  /// Every customer ended with an invoice.
  bool get allIssued => lines.isNotEmpty && issued.length == lines.length;

  /// What refused [memberId], to be worded by the shared helper; null when
  /// the customer was not refused.
  Refusal? refusalOf(String memberId) => switch (lines[memberId]?.outcome) {
    CommandRefused(:final refusal) => refusal,
    _ => null,
  };

  /// The invoice id of [memberId], when it exists.
  String? invoiceOf(String memberId) => switch (lines[memberId]?.outcome) {
    CommandDone(:final value) => value,
    _ => null,
  };

  MonthIssueReport _with(Map<String, MonthIssueLine> changed) =>
      MonthIssueReport({...lines, ...changed});
}

/// Issues [memberIds]' invoices for [period], one after the other, each once.
/// [onProgress] tells the flow which line is working, so its own button shows
/// the progress and nothing else waits. Customers whose answer was lost are
/// looked up once at the end.
Future<MonthIssueReport> issueMonth({
  required InvoiceIssuance issuance,
  required String workspaceId,
  required String period,
  required List<String> memberIds,
  String Function() requestId = newRequestId,
  void Function(String memberId, MonthLineProgress progress)? onProgress,
}) async {
  final lines = <String, MonthIssueLine>{};
  for (final memberId in memberIds) {
    onProgress?.call(memberId, MonthLineProgress.issuing);
    final attempt = InvoiceIssueAttempt(
      workspaceId: workspaceId,
      memberId: memberId,
      period: period,
      requestId: requestId(),
      direct: true,
    );
    lines[memberId] = (attempt: attempt, outcome: await issuance.issue(attempt));
    onProgress?.call(memberId, MonthLineProgress.done);
  }
  return _lookAgain(issuance, MonthIssueReport(lines));
}

/// Looks up every customer whose answer was lost (never sends again).
Future<MonthIssueReport> _lookAgain(
  InvoiceIssuance issuance,
  MonthIssueReport report,
) async {
  final changed = <String, MonthIssueLine>{};
  for (final entry in report.lines.entries) {
    final (:attempt, :outcome) = entry.value;
    if (outcome is CommandUnreached<String>) {
      changed[entry.key] = (
        attempt: attempt,
        outcome: await issuance.look(attempt, outcome),
      );
    }
  }
  return report._with(changed);
}

/// "Retry for those only": the customers the server refused are issued again
/// under NEW request ids (the refusal was an answer, the cause may be fixed
/// now); the ones whose answer was lost are looked up, never resent. What
/// is issued or held stays as it is.
Future<MonthIssueReport> retryNotDone({
  required InvoiceIssuance issuance,
  required MonthIssueReport report,
  String Function() requestId = newRequestId,
  void Function(String memberId, MonthLineProgress progress)? onProgress,
}) async {
  final changed = <String, MonthIssueLine>{};
  for (final entry in report.lines.entries) {
    final (:attempt, :outcome) = entry.value;
    // A declined request is never asked again.
    if (outcome is! CommandRefused<String> || isDeclined(outcome.refusal)) {
      continue;
    }
    onProgress?.call(entry.key, MonthLineProgress.issuing);
    final again = InvoiceIssueAttempt(
      workspaceId: attempt.workspaceId,
      memberId: attempt.memberId,
      period: attempt.period,
      requestId: requestId(),
      direct: attempt.direct,
    );
    changed[entry.key] = (attempt: again, outcome: await issuance.issue(again));
    onProgress?.call(entry.key, MonthLineProgress.done);
  }
  return _lookAgain(issuance, report._with(changed));
}
