// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 2) -- the one door for what an issuer does to a quote. The server
// decides everything (who may, the revision, what is missing); the answer is a
// closed outcome the screen words, never an exception it has to guess at. A
// write is never retried here: a lost answer is [QuoteUnreached] and the
// screen reads the quote again before it offers anything.
import '../../../core/trace/trace_logger.dart';
import '../domain/customer_quote.dart';

sealed class QuoteCommandOutcome<T> {
  const QuoteCommandOutcome();
}

/// The server did it; [value] is its answer.
final class QuoteDone<T> extends QuoteCommandOutcome<T> {
  const QuoteDone(this.value);
  final T value;
}

/// The server refused: nothing was written.
final class QuoteRefused<T> extends QuoteCommandOutcome<T> {
  const QuoteRefused(this.refusal);
  final QuoteRefusal refusal;
}

/// The answer never came (a lost connection, an older host): whether it was
/// done is not known, so nothing is claimed.
final class QuoteUnreached<T> extends QuoteCommandOutcome<T> {
  const QuoteUnreached();
}

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
  Future<QuoteCommandOutcome<QuoteSaved>> saveDraft(
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

  Future<QuoteCommandOutcome<QuoteSaved>> amend(
    String workspaceId,
    String quoteId,
  ) => _run('quote not amended', () => _repository.amend(workspaceId, quoteId));

  Future<QuoteCommandOutcome<QuoteSent>> send(
    String workspaceId,
    String quoteId, {
    required int revision,
    required int version,
  }) => _run(
    'quote not sent',
    () => _repository.send(workspaceId, quoteId, revision: revision, version: version),
  );

  /// Records the customer's answer; the issuer's own record, never a signature.
  Future<QuoteCommandOutcome<void>> recordDecision(
    String workspaceId,
    String quoteId,
    QuoteDecisionInput decision,
  ) => _run(
    'quote decision not recorded',
    () => _repository.recordDecision(workspaceId, quoteId, decision),
  );

  /// Previews the invoice of an accepted quote: the real issuer's own preview,
  /// nothing issued, nothing numbered.
  Future<QuoteCommandOutcome<QuoteConversionPrep>> prepareConversion(
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
  Future<QuoteCommandOutcome<QuoteConverted>> convert(
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
    if (outcome is! QuoteUnreached<QuoteConverted>) return outcome;
    final now = await read(workspaceId, quoteId);
    final invoiceId = now?.invoiceId;
    return invoiceId == null
        ? outcome
        : QuoteDone(QuoteConverted(invoiceId: invoiceId, number: '', replayed: true));
  }

  Future<QuoteCommandOutcome<void>> cancel(String workspaceId, String quoteId) =>
      _run('quote not cancelled', () => _repository.cancel(workspaceId, quoteId));

  Future<QuoteCommandOutcome<void>> discardDraft(
    String workspaceId,
    String quoteId,
  ) => _run(
    'quote draft not discarded',
    () => _repository.discardDraft(workspaceId, quoteId),
  );

  Future<QuoteCommandOutcome<T>> _run<T>(
    String what,
    Future<T> Function() send,
  ) async {
    try {
      return QuoteDone(await send());
    } on Object catch (e, st) {
      TraceLogger.instance.warn('money', what, error: e, stackTrace: st);
      return e is QuoteRefusal ? QuoteRefused<T>(e) : QuoteUnreached<T>();
    }
  }
}
