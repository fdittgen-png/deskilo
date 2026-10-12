// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1832 A — the sentence and the ONE recovery each typed connection
// outcome leads to. A screen asks these instead of parsing exceptions.
import '../../../core/backend/connection_outcome.dart';
import '../../../l10n/app_localizations.dart';

/// What the person can do about a failed connection, per target.
enum ConnectionRecovery {
  /// Sign in to this target again (the saved address and key are kept).
  signIn,

  /// Ask again later: a bounded retry of a read, never of a mutation.
  retry,

  /// Re-verify a quarantined target by connecting it again.
  verify,

  /// Nothing to retry here (an update or a different address is needed).
  none,
}

ConnectionRecovery connectionRecovery(ConnectionFailureReason reason) =>
    switch (reason) {
      ConnectionFailureReason.expired ||
      ConnectionFailureReason.denied => ConnectionRecovery.signIn,
      ConnectionFailureReason.unavailable ||
      ConnectionFailureReason.malformed ||
      ConnectionFailureReason.cancelled => ConnectionRecovery.retry,
      ConnectionFailureReason.changedIdentity => ConnectionRecovery.verify,
      ConnectionFailureReason.unsupported ||
      ConnectionFailureReason.invalidEndpoint ||
      ConnectionFailureReason.notConnected ||
      ConnectionFailureReason.currentServer => ConnectionRecovery.none,
    };

/// The sentence for [failure]. A transport loss after the request was sent
/// says the outcome is unknown — never that the action failed.
String connectionFailureText(AppLocalizations l, ConnectionFailure failure) {
  if (failure.afterSend &&
      failure.reason == ConnectionFailureReason.unavailable) {
    return l.connectionUnknownOutcome;
  }
  return switch (failure.reason) {
    ConnectionFailureReason.unsupported =>
      l.connectionUnsupported,
    ConnectionFailureReason.expired =>
      l.connectionExpired,
    ConnectionFailureReason.denied =>
      l.connectionDenied,
    ConnectionFailureReason.unavailable =>
      l.connectionUnavailable,
    ConnectionFailureReason.changedIdentity =>
      l.connectionChangedIdentity,
    ConnectionFailureReason.invalidEndpoint =>
      l.connectionInvalidEndpoint,
    ConnectionFailureReason.notConnected =>
      l.connectionNotConnected,
    ConnectionFailureReason.currentServer =>
      l.connectionCurrentServer,
    ConnectionFailureReason.cancelled =>
      l.connectionCancelled,
    ConnectionFailureReason.malformed =>
      l.connectionMalformed,
  };
}
