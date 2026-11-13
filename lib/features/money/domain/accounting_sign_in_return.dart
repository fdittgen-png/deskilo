// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3906 — what an accounting target's sign-in hands back to the app, and how
// completing it ended. The code and the state are a one-time credential:
// held in memory between the address and the page that completes the
// sign-in, never stored, logged or shown.

/// The address the target's redirect sends the browser on to.
const String accountingSignInReturnPath = '/accounting/connected';

/// What the target's redirect carried.
final class SignInReturn {
  const SignInReturn({
    required this.state,
    this.code = '',
    this.error = '',
    this.tenant = '',
  });

  /// The parameters of [uri], or null when it is not a sign-in return.
  static SignInReturn? fromUri(Uri uri) {
    final q = uri.queryParameters;
    final state = q['state'] ?? '';
    if (uri.path != accountingSignInReturnPath || state.isEmpty) return null;
    return SignInReturn(
      state: state,
      code: q['code'] ?? '',
      error: q['error'] ?? '',
      tenant: q['tenant'] ?? '',
    );
  }

  final String state;
  final String code;

  /// The target's word for a sign-in the person did not complete.
  final String error;

  /// The company the target's redirect names (QuickBooks), or empty.
  final String tenant;

  @override
  String toString() => 'SignInReturn(…)';
}

/// How completing a sign-in ended.
enum SignInCompletion {
  /// The connection is made.
  connected,

  /// The signed-in person may not manage this connection.
  refused,

  /// Someone else started this sign-in: only they complete it.
  startedBySomeoneElse,

  /// The sign-in link was used already, or is too old.
  expired,

  /// The target refused, or the sign-in was not completed there.
  failed,
}
