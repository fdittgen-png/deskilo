// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1649 — the recovery flow's decisions, out of the widget (#1234, ADR
// 0024): which call this step makes, where the answer moves the flow,
// and what — beyond the answer's own sentence — the sheet has to say.
// The sheet keeps the controllers and the busy flag; this keeps the
// step, and it is what a test drives with a fake repository and no tree.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/auth_outcome.dart';
import '../domain/auth_repository.dart';
import '../providers/auth_providers.dart';

part 'password_recovery.g.dart';

/// Three steps, because the answers are three: a code is sent, a code is
/// accepted, a password is saved — and the second without the third is
/// its own place, not a bad code.
enum RecoveryStep { request, verify, retryUpdate }

/// What the sheet says after a turn.
enum RecoveryNotice {
  /// Nothing beyond the step's own explainer.
  none,

  /// The result's own sentence ([authOutcomeText]).
  outcome,

  /// The session a code opened is gone; only a new code opens another.
  sessionLost,
}

typedef RecoveryTurn = ({
  RecoveryStep step,
  RecoveryNotice notice,
  AuthResult result,
});

class PasswordRecovery {
  PasswordRecovery(this._repo);

  final AuthRepository _repo;

  RecoveryStep _step = RecoveryStep.request;
  RecoveryStep get step => _step;

  bool _spent = false;

  /// True from the moment a code was accepted until the update lands:
  /// the session that exists meanwhile must not outlive the flow.
  bool get spent => _spent;

  /// Runs the current step's operation and moves the flow by its answer.
  Future<RecoveryTurn> submit({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final from = _step;
    final result = switch (from) {
      RecoveryStep.request => await _repo.requestPasswordReset(email),
      RecoveryStep.verify => await _repo.confirmPasswordReset(
          email: email,
          code: code,
          newPassword: newPassword,
        ),
      // The spent code is never sent again: only the update is retried.
      RecoveryStep.retryUpdate => await _repo.updateRecoveredPassword(
          newPassword,
        ),
    };
    var notice = RecoveryNotice.outcome;
    switch (result.outcome) {
      case AuthOutcome.completed:
        _spent = false;
        notice = RecoveryNotice.none;
      case AuthOutcome.recoveryVerificationRequired:
        // The code went out — or, later, the session was found gone.
        _spent = false;
        _step = RecoveryStep.verify;
        notice = from == RecoveryStep.request
            ? RecoveryNotice.none
            : RecoveryNotice.sessionLost;
      case AuthOutcome.recoverySessionReadyButPasswordNotUpdated:
        // The retry step's explainer says it; the sentence repeats only
        // when a retry failed the same way again.
        _spent = true;
        _step = RecoveryStep.retryUpdate;
        notice = from == RecoveryStep.retryUpdate
            ? RecoveryNotice.outcome
            : RecoveryNotice.none;
      default:
        break;
    }
    return (step: _step, notice: notice, result: result);
  }

  /// On the way out, whatever the step: a session a spent code opened
  /// must not outlive the flow. Nothing to clean up when none was.
  Future<void> abandon() =>
      _spent ? _repo.cancelPasswordRecovery() : Future.value();
}

/// One flow per sheet: the provider is not kept alive, so a sheet opened
/// later starts at the request step again.
@riverpod
PasswordRecovery passwordRecovery(Ref ref) =>
    PasswordRecovery(ref.watch(authRepositoryProvider));
