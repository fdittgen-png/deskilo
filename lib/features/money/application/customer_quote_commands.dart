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
