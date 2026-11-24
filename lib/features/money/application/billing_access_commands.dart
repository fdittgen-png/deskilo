// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 B2 -- the one door for the billing-access grants. Nothing is sent for a
// code or a reason the pure rules refuse; the server decides who may and whether
// the code can be used. The answer is a closed outcome the screens word, never an
// exception they have to guess at.
import '../../../core/data/app_failure_from.dart';
import '../../../core/failure/app_failure.dart';
import '../domain/billing_access.dart';

class BillingAccessCommands {
  const BillingAccessCommands(this._repository);

  final BillingAccessRepository _repository;

  /// The grants of one subject; a refusal is an outcome, never "no grants".
  Future<CommandOutcome<List<BillingAccessGrant>>> grantsOf(
    String workspaceId,
    String subjectId,
  ) => _run(() => _repository.grantsOf(workspaceId, subjectId));

  /// Invites [subjectId]. Retrying with the same [requestId] answers the same
  /// invitation (the server replays it), so a lost answer is recovered, never
  /// doubled.
  Future<CommandOutcome<BillingAccessInvitation>> invite(
    String workspaceId,
    String subjectId,
    String requestId,
  ) => _run(() => _repository.invite(workspaceId, subjectId, requestId));

  Future<CommandOutcome<BillingAccessPreview>> preview(String code) {
    final wanted = normaliseBillingCode(code);
    if (wanted.isEmpty) {
      return Future.value(_invalid(BillingAccessRefusalKind.codeUnusable));
    }
    return _run(() => _repository.preview(wanted));
  }

  Future<CommandOutcome<BillingAccessAccepted>> accept(String code) {
    final wanted = normaliseBillingCode(code);
    if (wanted.isEmpty) {
      return Future.value(_invalid(BillingAccessRefusalKind.codeUnusable));
    }
    return _run(() => _repository.accept(wanted));
  }

  Future<CommandOutcome<void>> revoke(
    String grantId, {
    String reason = '',
  }) {
    if (reason.trim().length > billingRevokeReasonMax) {
      return Future.value(_invalid(BillingAccessRefusalKind.reasonTooLong));
    }
    return _run(() => _repository.revoke(grantId, reason: reason.trim()));
  }

  /// Refused by the rules before anything is sent (an empty code, a long
  /// reason): a local refusal, with its kind as the cause.
  CommandOutcome<T> _invalid<T>(BillingAccessRefusalKind kind) =>
      CommandRefused<T>(Refusal(cause: BillingAccessRefusal(kind)));

  /// Runs [send]: done, refused with its [BillingAccessRefusal] as the cause,
  /// or not reached; logged once.
  Future<CommandOutcome<T>> _run<T>(Future<T> Function() send) =>
      runCommand(send, what: 'billing access not done');

}
