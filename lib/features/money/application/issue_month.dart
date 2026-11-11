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
import '../../../core/ids/request_id.dart';
import 'issue_invoice.dart';

/// Where one customer stands while the month is issued.
enum MonthLineProgress { waiting, issuing, done }

/// What happened to every ticked customer, in the order they were ticked.
final class MonthIssueReport {
  const MonthIssueReport(this.outcomes);

  /// One outcome per customer, by member id, in ticking order.
  final Map<String, InvoiceIssueOutcome> outcomes;

  Iterable<String> _of(bool Function(InvoiceIssueOutcome) test) => [
    for (final e in outcomes.entries)
      if (test(e.value)) e.key,
  ];

  /// The invoice exists.
  List<String> get issued => _of((o) => o is InvoiceIssued).toList();

  /// A validation policy holds the request: nothing was issued yet.
  List<String> get held => _of((o) => o is InvoiceIssueHeld).toList();

  /// The server said no, in words: retry may help once the cause is fixed.
  /// A request a validator declined is not one of these (see [declined]).
  List<String> get refused => _of(
    (o) => o is InvoiceIssueRefused && o.error is! InvoiceIssueDeclined,
  ).toList();

  /// A validator declined the request: it is not retried, a new request would
  /// ask the same question again.
  List<String> get declined => _of(
    (o) => o is InvoiceIssueRefused && o.error is InvoiceIssueDeclined,
  ).toList();

  /// The answer was lost: the invoice may exist; only looking again helps.
  List<String> get unknown => _of((o) => o is InvoiceIssueUnknown).toList();

  /// What did not end in an invoice or a held request.
  List<String> get notDone => [...refused, ...declined, ...unknown];

  /// Every customer ended with an invoice.
  bool get allIssued => outcomes.isNotEmpty && issued.length == outcomes.length;

  /// What refused [memberId], to be worded by the shared helper; null when
  /// the customer was not refused.
  Object? refusalOf(String memberId) {
    final o = outcomes[memberId];
    return o is InvoiceIssueRefused ? o.error : null;
  }

  /// The invoice id of [memberId], when it exists.
  String? invoiceOf(String memberId) {
    final o = outcomes[memberId];
    return o is InvoiceIssued ? o.invoiceId : null;
  }

  MonthIssueReport _with(Map<String, InvoiceIssueOutcome> changed) =>
      MonthIssueReport({...outcomes, ...changed});
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
  final outcomes = <String, InvoiceIssueOutcome>{};
  for (final memberId in memberIds) {
    onProgress?.call(memberId, MonthLineProgress.issuing);
    outcomes[memberId] = await issuance.issue(
      InvoiceIssueAttempt(
        workspaceId: workspaceId,
        memberId: memberId,
        period: period,
        requestId: requestId(),
        direct: true,
      ),
    );
    onProgress?.call(memberId, MonthLineProgress.done);
  }
  return _lookAgain(issuance, MonthIssueReport(outcomes));
}

/// Looks up every customer whose answer was lost (never sends again).
Future<MonthIssueReport> _lookAgain(
  InvoiceIssuance issuance,
  MonthIssueReport report,
) async {
  final changed = <String, InvoiceIssueOutcome>{};
  for (final entry in report.outcomes.entries) {
    final outcome = entry.value;
    if (outcome is InvoiceIssueUnknown) {
      changed[entry.key] = await issuance.look(outcome);
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
  final changed = <String, InvoiceIssueOutcome>{};
  for (final entry in report.outcomes.entries) {
    final outcome = entry.value;
    // A declined request is never asked again.
    if (outcome is! InvoiceIssueRefused ||
        outcome.error is InvoiceIssueDeclined) {
      continue;
    }
    final attempt = outcome.attempt;
    onProgress?.call(entry.key, MonthLineProgress.issuing);
    changed[entry.key] = await issuance.issue(
      InvoiceIssueAttempt(
        workspaceId: attempt.workspaceId,
        memberId: attempt.memberId,
        period: attempt.period,
        requestId: requestId(),
        direct: attempt.direct,
      ),
    );
    onProgress?.call(entry.key, MonthLineProgress.done);
  }
  return _lookAgain(issuance, report._with(changed));
}
