// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 A2 -- the one door for a billing customer's create and edit. The pure
// rules are checked first (nothing is sent for a draft that cannot be saved);
// the server decides who may and whether the record is still the one that was
// read. The answer is a closed outcome the editor words, never an exception it
// has to guess at.
import '../../../core/data/app_failure_from.dart';
import '../../../core/failure/app_failure.dart';
import '../domain/billing_customer.dart';

class BillingCustomerCommands {
  const BillingCustomerCommands(this._repository);

  final BillingCustomerRepository _repository;

  /// The rules a form shows under its fields.
  Map<String, BillingPartyProblem> check(BillingPartyDraft draft) =>
      validateBillingParty(draft);

  /// Creates a customer with no account. [capacity] is sent only when stated.
  Future<CommandOutcome<String>> create(
    String workspaceId,
    BillingPartyDraft draft, {
    String? capacity,
  }) => _run(draft, () async {
    return _repository.create(workspaceId, draft, capacity: capacity);
  });

  /// Edits [existing] at the revision it was read.
  Future<CommandOutcome<String>> save(
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
    return saved.subjectId;
  });

  /// Checks [draft] first (nothing is sent for one that breaks a rule), then
  /// runs [send]: done with the customer's subject, refused with its
  /// [BillingCustomerRefusal] or [BillingDraftInvalid] as the cause, or not
  /// reached; logged once.
  Future<CommandOutcome<String>> _run(
    BillingPartyDraft draft,
    Future<String> Function() send,
  ) {
    final problems = validateBillingParty(draft);
    if (problems.isNotEmpty) {
      return Future.value(
        CommandRefused(Refusal(cause: BillingDraftInvalid(problems))),
      );
    }
    return runCommand(send, what: 'billing customer not saved');
  }

}
