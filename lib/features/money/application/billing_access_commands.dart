// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 B2 -- the one door for the billing-access grants. Nothing is sent for a
// code or a reason the pure rules refuse; the server decides who may and whether
// the code can be used. The answer is a closed outcome the screens word, never an
// exception they have to guess at.
import '../../../core/trace/trace_logger.dart';
import '../domain/billing_access.dart';

sealed class BillingAccessOutcome<T> {
  const BillingAccessOutcome();
}

/// Done; [value] is what the server answered.
final class BillingAccessDone<T> extends BillingAccessOutcome<T> {
  const BillingAccessDone(this.value);
  final T value;
}

/// The rules say so before anything is sent (an empty code, a long reason).
final class BillingAccessInvalid<T> extends BillingAccessOutcome<T> {
  const BillingAccessInvalid(this.kind);
  final BillingAccessRefusalKind kind;
}

/// The server refused: nothing was written.
final class BillingAccessRefused<T> extends BillingAccessOutcome<T> {
  const BillingAccessRefused(this.kind);
  final BillingAccessRefusalKind kind;
}

/// The answer never came (a lost connection, an older host): nothing is
/// claimed done, and the screen offers the retry.
final class BillingAccessUnreached<T> extends BillingAccessOutcome<T> {
  const BillingAccessUnreached();
}

class BillingAccessCommands {
  const BillingAccessCommands(this._repository);

  final BillingAccessRepository _repository;

  /// The grants of one subject; a refusal is an outcome, never "no grants".
  Future<BillingAccessOutcome<List<BillingAccessGrant>>> grantsOf(
    String workspaceId,
    String subjectId,
  ) => _run(() => _repository.grantsOf(workspaceId, subjectId));

  /// Invites [subjectId]. Retrying with the same [requestId] answers the same
  /// invitation (the server replays it), so a lost answer is recovered, never
  /// doubled.
  Future<BillingAccessOutcome<BillingAccessInvitation>> invite(
    String workspaceId,
    String subjectId,
    String requestId,
  ) => _run(() => _repository.invite(workspaceId, subjectId, requestId));

  Future<BillingAccessOutcome<BillingAccessPreview>> preview(String code) {
    final wanted = normaliseBillingCode(code);
    if (wanted.isEmpty) {
      return Future.value(
        const BillingAccessInvalid(BillingAccessRefusalKind.codeUnusable),
      );
    }
    return _run(() => _repository.preview(wanted));
  }

  Future<BillingAccessOutcome<BillingAccessAccepted>> accept(String code) {
    final wanted = normaliseBillingCode(code);
    if (wanted.isEmpty) {
      return Future.value(
        const BillingAccessInvalid(BillingAccessRefusalKind.codeUnusable),
      );
    }
    return _run(() => _repository.accept(wanted));
  }

  Future<BillingAccessOutcome<void>> revoke(
    String grantId, {
    String reason = '',
  }) {
    if (reason.trim().length > billingRevokeReasonMax) {
      return Future.value(
        const BillingAccessInvalid(BillingAccessRefusalKind.reasonTooLong),
      );
    }
    return _run(() => _repository.revoke(grantId, reason: reason.trim()));
  }

  Future<BillingAccessOutcome<T>> _run<T>(Future<T> Function() send) async {
    try {
      return BillingAccessDone(await send());
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        e is BillingAccessRefusal
            ? 'billing access refused'
            : 'billing access not reached',
        error: e,
        stackTrace: st,
      );
      return e is BillingAccessRefusal
          ? BillingAccessRefused(e.kind)
          : const BillingAccessUnreached();
    }
  }
}
