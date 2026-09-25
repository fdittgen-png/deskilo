// SPDX-License-Identifier: AGPL-3.0-or-later

/// What a native authentication operation actually did (#1649).
///
/// Every operation used to answer `void` or throw, and the screen
/// inferred the rest: a sign-up that came back "200, no session" read as
/// a sign-in that somehow signed nobody in, and a recovery whose update
/// failed AFTER its code was redeemed read as a bad code — sending the
/// person back to redeem a code already spent. Each is its own outcome.
///
/// Pending, empty, refused and failed are four different things (#1561,
/// #1563, #1580): a request the server has not judged ([rateLimited],
/// [unavailable]) never wears the words of one it has.
enum AuthOutcome {
  /// A session exists. The router takes it from here.
  authenticated,

  /// No session: an e-mail with the next step went out. Whether the
  /// account is new or already existed the server does not say, on
  /// purpose, and neither does this.
  verificationRequired,

  /// A recovery code went out; the next step is entering it.
  recoveryVerificationRequired,

  /// The recovery code was accepted — and is therefore spent — but the
  /// new password did not land. The session is live for one purpose:
  /// retrying the update.
  recoverySessionReadyButPasswordNotUpdated,

  /// The password was updated; the person is signed in with it.
  completed,

  /// The server judged the request and said no; [AuthResult.refusal]
  /// says why, as far as the server itself said.
  refused,

  /// The server declined to judge it yet; [AuthResult.retryAfter] when
  /// it said how long.
  rateLimited,

  /// Nothing was judged: no network, a 5xx, an answer that did not parse.
  unavailable,
}

/// Why the server refused — never more than it disclosed itself.
enum AuthRefusal {
  /// Wrong e-mail or password, or any refusal the server left unnamed.
  /// Same words for both, so a probe learns nothing from the difference.
  credentials,

  /// The account exists but its address was never confirmed.
  emailNotConfirmed,

  /// E-mail sign-in, sign-ups or codes are switched off on this server.
  providerDisabled,

  /// Sign-up only, and only when the server chose to disclose it
  /// (enumeration protection off); with it on, the same request answers
  /// [AuthOutcome.verificationRequired] and this never appears.
  alreadyRegistered,

  /// The server's password policy refused the new password.
  weakPassword,

  /// A one-time code that is wrong, expired or already redeemed.
  codeInvalid,
}

/// One operation's answer: the outcome and what little detail is safe.
class AuthResult {
  const AuthResult._(this.outcome, {this.refusal, this.retryAfter, this.trace});

  const AuthResult.authenticated() : this._(AuthOutcome.authenticated);
  const AuthResult.verificationRequired()
      : this._(AuthOutcome.verificationRequired);
  const AuthResult.recoveryVerificationRequired()
      : this._(AuthOutcome.recoveryVerificationRequired);
  const AuthResult.recoverySessionReadyButPasswordNotUpdated({String? trace})
      : this._(AuthOutcome.recoverySessionReadyButPasswordNotUpdated,
            trace: trace);
  const AuthResult.completed() : this._(AuthOutcome.completed);
  const AuthResult.refused(AuthRefusal refusal, {String? trace})
      : this._(AuthOutcome.refused, refusal: refusal, trace: trace);
  const AuthResult.rateLimited({Duration? retryAfter, String? trace})
      : this._(AuthOutcome.rateLimited, retryAfter: retryAfter, trace: trace);
  const AuthResult.unavailable({String? trace})
      : this._(AuthOutcome.unavailable, trace: trace);

  final AuthOutcome outcome;

  /// Set only for [AuthOutcome.refused].
  final AuthRefusal? refusal;

  /// Set for [AuthOutcome.rateLimited] when the server named a wait.
  final Duration? retryAfter;

  /// The server's error CODE (`otp_expired`, `429`, …), never its message,
  /// which may quote what was typed. The trace records this; the words
  /// the person sees come from the outcome.
  final String? trace;

  @override
  String toString() => 'AuthResult($outcome'
      '${refusal == null ? '' : ', $refusal'}'
      '${retryAfter == null ? '' : ', retry after $retryAfter'}'
      '${trace == null ? '' : ', trace $trace'})';
}

/// How long the app waits before offering an e-mail again when the
/// server did not name a wait itself — gotrue's own minimum between two
/// e-mails to one address, so the button comes back when a send can
/// succeed rather than a second before a 429.
abstract final class AuthCooldowns {
  static const Duration resend = Duration(seconds: 60);
}
