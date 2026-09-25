// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1649 — the check-e-mail state's one decision, out of the widget
// (#1234, ADR 0024): after a resend, how long the next offer is held.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/auth_outcome.dart';
import '../domain/auth_repository.dart';
import '../providers/auth_providers.dart';

part 'sign_up_verification.g.dart';

typedef ResendTurn = ({AuthResult result, Duration? holdFor});

class SignUpVerification {
  SignUpVerification(this._repo);

  final AuthRepository _repo;

  /// Sends the confirmation e-mail again. [ResendTurn.holdFor] is how
  /// long the next offer stays closed: a send that went out and a send
  /// the server deferred both mean "not again yet" — for the server's own
  /// wait when it named one, else the default. Null when sending again
  /// IS the remedy (a refusal, an outage): nothing to wait for.
  Future<ResendTurn> resend(String email) async {
    final result = await _repo.resendSignUpVerification(email);
    final hold = switch (result.outcome) {
      AuthOutcome.verificationRequired ||
      AuthOutcome.rateLimited =>
        result.retryAfter ?? AuthCooldowns.resend,
      _ => null,
    };
    return (result: result, holdFor: hold);
  }
}

@riverpod
SignUpVerification signUpVerification(Ref ref) =>
    SignUpVerification(ref.watch(authRepositoryProvider));
