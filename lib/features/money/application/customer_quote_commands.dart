// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 2) -- the one door for what an issuer does to a quote. The server
// decides everything (who may, the revision, what is missing); the answer is a
// closed outcome the screen words, never an exception it has to guess at. A
// write is never retried here: a lost answer is [CommandUnreached] and the
// screen reads the quote again before it offers anything.
import '../../../core/data/app_failure_from.dart';
import '../../../core/failure/app_failure.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/customer_quote.dart';

class CustomerQuoteCommands {
  const CustomerQuoteCommands(this._repository);

  final CustomerQuoteRepository _repository;

  /// The quote as the server answers it now, or null when it could not be read
  /// (the screen only reads it to keep the line identities across saves).
  Future<CustomerQuote?> read(String workspaceId, String quoteId) async {
    try {
      return await _repository.quote(workspaceId, quoteId);
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'a quote could not be read back',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Creates a quote ([quoteId] null) or edits its working draft at [expectedVersion].
  Future<CommandOutcome<QuoteSaved>> saveDraft(
    String workspaceId, {
    required QuoteDraftInput input,
    String? quoteId,
    int? expectedVersion,
  }) => _run(
    'quote draft not saved',
    () => _repository.saveDraft(
      workspaceId,
      input: input,
      quoteId: quoteId,
      expectedVersion: expectedVersion,
    ),
  );

  Future<CommandOutcome<QuoteSaved>> amend(
    String workspaceId,
    String quoteId,
  ) => _run('quote not amended', () => _repository.amend(workspaceId, quoteId));

  Future<CommandOutcome<QuoteSent>> send(
    String workspaceId,
    String quoteId, {
    required int revision,
    required int version,
  }) => _run(
    'quote not sent',
    () => _repository.send(workspaceId, quoteId, revision: revision, version: version),
  );

  /// Records the customer's answer; the issuer's own record, never a signature.
  Future<CommandOutcome<void>> recordDecision(
    String workspaceId,
    String quoteId,
    QuoteDecisionInput decision,
  ) => _run(
    'quote decision not recorded',
    () => _repository.recordDecision(workspaceId, quoteId, decision),
  );

  /// Previews the invoice of an accepted quote: the real issuer's own preview,
  /// nothing issued, nothing numbered.
  Future<CommandOutcome<QuoteConversionPrep>> prepareConversion(
    String workspaceId,
    String quoteId, {
    required DateTime serviceDate,
    required DateTime dueOn,
  }) => _run(
    'quote conversion not prepared',
    () => _repository.prepareConversion(
      workspaceId,
      quoteId,
      serviceDate: serviceDate,
      dueOn: dueOn,
    ),
  );

  /// Issues the one initial invoice of an accepted quote. [requestId] is drawn
  /// once per confirmed review: a second tap is the same attempt, and the server
  /// answers the same invoice whatever the request. A lost answer is looked up
  /// in the quote itself (its recorded conversion) before anything is offered.
  Future<CommandOutcome<QuoteConverted>> convert(
    String workspaceId,
    String quoteId, {
    required int draftRevision,
    required String requestId,
    String? reviewedDigest,
  }) async {
    final outcome = await _run<QuoteConverted>(
      'quote not converted',
      () => _repository.convert(
        workspaceId,
        quoteId,
        draftRevision: draftRevision,
        requestId: requestId,
        reviewedDigest: reviewedDigest,
      ),
    );
    // Done, or refused by the quote's own rules: the answer is known. Anything
    // else may have converted it: the quote says.
    final known = switch (outcome) {
      CommandDone() => true,
      CommandRefused(refusal: Refusal(cause: QuoteRefusal())) => true,
      _ => false,
    };
    if (known) return outcome;
    final now = await read(workspaceId, quoteId);
    final invoiceId = now?.invoiceId;
    return invoiceId == null
        ? outcome
        : CommandDone(QuoteConverted(invoiceId: invoiceId, number: '', replayed: true));
  }

  Future<CommandOutcome<void>> cancel(String workspaceId, String quoteId) =>
      _run('quote not cancelled', () => _repository.cancel(workspaceId, quoteId));

  Future<CommandOutcome<void>> discardDraft(
    String workspaceId,
    String quoteId,
  ) => _run(
    'quote draft not discarded',
    () => _repository.discardDraft(workspaceId, quoteId),
  );

  /// Runs [send]: done, refused with its [QuoteRefusal] as the cause, or
  /// not reached; logged once under [what].
  Future<CommandOutcome<T>> _run<T>(String what, Future<T> Function() send) =>
      runCommand(send, what: what);

}
