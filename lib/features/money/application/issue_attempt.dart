// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4405 -- ONE issue attempt for a document that is checked before it is issued: a standalone invoice, the invoice of an accepted
// quote. It holds what both screens used to hold each: the document the server says it would freeze, what it cannot accept, the
// request identity drawn once per checked document (a second tap is the same attempt), an answer that did not come, and the look
// at the receipt of THAT request before anything else is offered. The screen words what it shows; the attempt decides nothing a
// screen decides: whether the person may issue (a review, a customer) stays the screen's, asked before [issue].
import '../../../core/failure/app_failure.dart';
import '../../../core/ids/request_id.dart';
import '../domain/previewed_document.dart';

/// What a check answers: the document as the server would freeze it, and what the issue is made of ([basis]: the saved draft, the
/// prepared conversion).
typedef Checked<C> = ({C basis, PreviewedDocument document});

/// Sends the issue under [requestId].
typedef SendIssue<T> = Future<CommandOutcome<T>> Function(String requestId);

/// Reads the receipt of the request [requestId] (never writes): the document it made, or [unknown] again.
typedef LookIssue<T> = Future<CommandOutcome<T>> Function(String requestId, CommandUnreached<T> unknown);

final class IssueAttempt<C, T> {
  /// [onChanged] repaints the screen; [keysOf] names the facts a refusal says are missing (none for a screen that words the refusal itself).
  IssueAttempt({required this.onChanged, this.keysOf = _noKeys});

  final void Function() onChanged;
  final List<String> Function(Refusal refusal) keysOf;

  /// What the last check made the issue of, and the document it would freeze; null until a check answered, or after an edit.
  C? basis;
  PreviewedDocument? document;

  /// The facts the server named as missing (the check's, or a refusal's), and the refusal itself when there was one.
  List<String> missing = const [];
  Refusal? refusal;

  /// A check or an issue is under way.
  bool busy = false;

  /// The check did not get an answer (not a refusal): nothing is known.
  bool checkUnreached = false;

  /// An issue whose answer did not come: the only thing offered is [lookAgain].
  CommandUnreached<T>? unknown;

  String? _requestId;
  LookIssue<T>? _look;

  static List<String> _noKeys(Refusal _) => const [];

  /// Whether the issue was sent and its answer is not known.
  bool get isUnknown => unknown != null;

  /// A check was refused or what it names is missing.
  bool get refused => refusal != null || missing.isNotEmpty;

  /// Any edit makes the checked document stale: the next check makes a new one, under a new request.
  void edited() {
    basis = null;
    document = null;
    missing = const [];
    refusal = null;
    checkUnreached = false;
    _requestId = null;
    onChanged();
  }

  /// Asks the server what [run] would freeze. A refusal is kept (and its missing facts named); a check that got no answer says so.
  Future<void> check(Future<CommandOutcome<Checked<C>>> Function() run) async {
    busy = true;
    refusal = null;
    checkUnreached = false;
    onChanged();
    final outcome = await run();
    busy = false;
    switch (outcome) {
      case CommandDone(:final value):
        basis = value.basis;
        document = value.document;
        missing = value.document.missing;
        _requestId = null;
      case CommandRefused(refusal: final r):
        basis = null;
        document = null;
        refusal = r;
        missing = keysOf(r);
      case CommandUnreached() || CommandHeld():
        basis = null;
        document = null;
        checkUnreached = true;
    }
    onChanged();
  }

  /// Sends the issue of the checked document: one identity per checked document, so a second tap is the same attempt. Answers the
  /// outcome for the screen to act on (go to the invoice, say it was held), or null when nothing was checked.
  Future<CommandOutcome<T>?> issue({required SendIssue<T> send, required LookIssue<T> look}) async {
    if (basis == null) return null;
    final id = _requestId ??= newRequestId();
    _look = look;
    busy = true;
    onChanged();
    return _settle(await send(id));
  }

  /// Reads the receipt of the request that was sent: the document it made, or the same unknown answer.
  Future<CommandOutcome<T>?> lookAgain() async {
    final u = unknown;
    final id = _requestId;
    final look = _look;
    if (u == null || id == null || look == null) return null;
    busy = true;
    onChanged();
    return _settle(await look(id, u));
  }

  CommandOutcome<T> _settle(CommandOutcome<T> outcome) {
    busy = false;
    switch (outcome) {
      case CommandRefused(refusal: final r):
        // a definite no: the checked document no longer stands
        unknown = null;
        refusal = r;
        missing = keysOf(r);
        document = null;
        basis = null;
      case CommandUnreached():
        unknown = outcome;
      case CommandDone() || CommandHeld():
        unknown = null;
    }
    onChanged();
    return outcome;
  }
}
