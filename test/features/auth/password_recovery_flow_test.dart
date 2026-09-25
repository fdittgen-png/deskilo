// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1649 — the recovery flow's decisions, driven without a widget tree:
// each step makes its own call, a spent code moves the flow to the
// retry step and is never redeemed again, a session found gone sends it
// back to the code step with its own notice, and abandoning the flow
// cleans up only when a spent code left a session behind.
import 'package:deskilo/features/auth/application/password_recovery.dart';
import 'package:deskilo/features/auth/domain/auth_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

const _notSaved = AuthResult.recoverySessionReadyButPasswordNotUpdated();

void main() {
  late FakeAuthRepository auth;
  late PasswordRecovery flow;

  setUp(() {
    auth = FakeAuthRepository();
    flow = PasswordRecovery(auth);
  });

  Future<RecoveryTurn> submit({String code = '123456'}) => flow.submit(
        email: 'flo@example.com',
        code: code,
        newPassword: 'brandnewpw',
      );

  test('request → verify → completed, one call per step', () async {
    final sent = await submit();
    expect(sent.step, RecoveryStep.verify);
    expect(sent.notice, RecoveryNotice.none);
    expect(auth.resetRequests, ['flo@example.com']);

    final done = await submit();
    expect(done.result.outcome, AuthOutcome.completed);
    expect(done.notice, RecoveryNotice.none);
    expect(auth.confirmedResets.single, ('flo@example.com', '123456', 'brandnewpw'));
    expect(flow.spent, isFalse);
  });

  test('a refused request stays at the request step with the sentence',
      () async {
    auth.resetRequestResult = const AuthResult.rateLimited();
    final turn = await submit();
    expect(turn.step, RecoveryStep.request);
    expect(turn.notice, RecoveryNotice.outcome);
  });

  test('a spent code moves to the retry step, silently the first time; '
      'the retry goes through the update seam, never the code again',
      () async {
    await submit();
    auth.confirmResetResult = _notSaved;
    final spent = await submit();
    expect(spent.step, RecoveryStep.retryUpdate);
    expect(spent.notice, RecoveryNotice.none);
    expect(flow.spent, isTrue);

    auth.updatePasswordResult = _notSaved;
    final again = await submit();
    expect(again.notice, RecoveryNotice.outcome, reason: 'failed again');
    expect(auth.passwordUpdates, ['brandnewpw']);
    expect(auth.confirmedResets, isEmpty);

    auth.updatePasswordResult = null;
    final done = await submit();
    expect(done.result.outcome, AuthOutcome.completed);
    expect(flow.spent, isFalse);
  });

  test('a retry that finds the session gone goes back to the code step',
      () async {
    await submit();
    auth.confirmResetResult = _notSaved;
    await submit();
    auth.updatePasswordResult = const AuthResult.recoveryVerificationRequired();
    final lost = await submit();
    expect(lost.step, RecoveryStep.verify);
    expect(lost.notice, RecoveryNotice.sessionLost);
    expect(flow.spent, isFalse);
  });

  test('abandon cleans up only after a spent code', () async {
    await flow.abandon();
    expect(auth.recoveryCancelled, isFalse);
    await submit();
    auth.confirmResetResult = _notSaved;
    await submit();
    await flow.abandon();
    expect(auth.recoveryCancelled, isTrue);
  });
}
