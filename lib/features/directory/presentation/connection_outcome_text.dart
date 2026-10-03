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
String connectionFailureText(AppLocalizations? l, ConnectionFailure failure) {
  if (failure.afterSend &&
      failure.reason == ConnectionFailureReason.unavailable) {
    return l?.connectionUnknownOutcome ??
        'The connection dropped after the request was sent. It may have been '
            'applied: check before trying again.';
  }
  return switch (failure.reason) {
    ConnectionFailureReason.unsupported =>
      l?.connectionUnsupported ??
          "This server's version cannot be connected from this app. Update "
              "the app, or ask the server's operator to update the server.",
    ConnectionFailureReason.expired =>
      l?.connectionExpired ??
          'Your sign-in to this server has ended. Sign in to this server '
              'again.',
    ConnectionFailureReason.denied =>
      l?.connectionDenied ??
          'This server refused the account. Check the sign-in details, or '
              'disconnect it.',
    ConnectionFailureReason.unavailable =>
      l?.connectionUnavailable ??
          'This server is not answering right now. Your other servers are '
              'not affected.',
    ConnectionFailureReason.changedIdentity =>
      l?.connectionChangedIdentity ??
          'This server is no longer the one you connected. Its actions are '
              'paused until you verify it again.',
    ConnectionFailureReason.invalidEndpoint =>
      l?.connectionInvalidEndpoint ??
          'This address or key is not a valid server.',
    ConnectionFailureReason.notConnected =>
      l?.connectionNotConnected ??
          'This server is not connected on this device.',
    ConnectionFailureReason.currentServer =>
      l?.connectionCurrentServer ?? 'This is the server this app already uses.',
    ConnectionFailureReason.cancelled =>
      l?.connectionCancelled ??
          'The account changed meanwhile, so this answer was discarded.',
    ConnectionFailureReason.malformed =>
      l?.connectionMalformed ??
          'This server answered something this app cannot read.',
  };
}
