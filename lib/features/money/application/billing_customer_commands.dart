// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 A2 -- the one door for a billing customer's create and edit. The pure
// rules are checked first (nothing is sent for a draft that cannot be saved);
// the server decides who may and whether the record is still the one that was
// read. The answer is a closed outcome the editor words, never an exception it
// has to guess at.
import '../../../core/trace/trace_logger.dart';
import '../domain/billing_customer.dart';

sealed class BillingCommandOutcome {
  const BillingCommandOutcome();
}

/// Saved; [subjectId] is the customer's subject (new for a creation).
final class BillingSaved extends BillingCommandOutcome {
  const BillingSaved(this.subjectId);
  final String subjectId;
}

/// The draft breaks a rule that needs no server to say so.
final class BillingInvalid extends BillingCommandOutcome {
  const BillingInvalid(this.problems);
  final Map<String, BillingPartyProblem> problems;
}

/// The server refused: nothing was written.
final class BillingRefused extends BillingCommandOutcome {
  const BillingRefused(this.kind);
  final BillingCustomerRefusalKind kind;
}

/// The answer never came (a lost connection, an older host): nothing is
/// claimed saved, and the editor offers the retry.
final class BillingUnreached extends BillingCommandOutcome {
  const BillingUnreached();
}

class BillingCustomerCommands {
  const BillingCustomerCommands(this._repository);

  final BillingCustomerRepository _repository;

  /// The rules a form shows under its fields.
  Map<String, BillingPartyProblem> check(BillingPartyDraft draft) =>
      validateBillingParty(draft);

  /// Creates a customer with no account. [capacity] is sent only when stated.
  Future<BillingCommandOutcome> create(
    String workspaceId,
    BillingPartyDraft draft, {
    String? capacity,
  }) => _run(draft, () async {
    final id = await _repository.create(workspaceId, draft, capacity: capacity);
    return BillingSaved(id);
  });

  /// Edits [existing] at the revision it was read.
  Future<BillingCommandOutcome> save(
    String workspaceId,
    BillingParty existing,
    BillingPartyDraft draft, {
    String? capacity,
  }) => _run(draft, () async {
    final saved = await _repository.save(
      workspaceId,
      existing.subjectId,
      draft,
      expectedRevision: existing.revision,
      capacity: capacity,
    );
    return BillingSaved(saved.subjectId);
  });

  Future<BillingCommandOutcome> _run(
    BillingPartyDraft draft,
    Future<BillingCommandOutcome> Function() send,
  ) async {
    final problems = validateBillingParty(draft);
    if (problems.isNotEmpty) return BillingInvalid(problems);
    try {
      return await send();
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        e is BillingCustomerRefusal
            ? 'billing customer refused'
            : 'billing customer not saved',
        error: e,
        stackTrace: st,
      );
      return e is BillingCustomerRefusal
          ? BillingRefused(e.kind)
          : const BillingUnreached();
    }
  }
}
