// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1832 A — why a connected installation could not be used, as a type.
//
// A connection used to fail with a sentence (`StateError('sign in again')`,
// `'installation changed'`, …), so every screen showed the same "could not
// connect" and offered the same retry. These outcomes lead to DIFFERENT
// recoveries: an unsupported server needs an update, an expired sign-in
// needs this target's sign-in again, an outage needs a bounded retry, and
// a changed installation is quarantined until someone re-verifies it.
// Retrying an uncertain mutation is never one of them.
//
// [ConnectionFailure] still is a [StateError], so the callers that only
// knew "it failed" keep working unchanged.
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../public_network/public_network_negotiator.dart';
import '../public_network/public_network_operations.dart';
import '../trace/trace_logger.dart';
import 'schema_version.dart';

enum ConnectionFailureReason {
  /// The server speaks no connection protocol this build speaks, or
  /// describes itself with a term this build cannot understand.
  unsupported,

  /// This target's sign-in ended: the session expired or its refresh
  /// token is no longer accepted. Sign in to THIS target again.
  expired,

  /// The target refused the account: wrong credentials, a banned or
  /// removed account, a revoked grant.
  denied,

  /// Nothing (or a server error) answered: offline, timeout, 5xx.
  unavailable,

  /// The target is no longer the installation (or the account) that was
  /// connected. Its protected actions are quarantined until re-verified.
  changedIdentity,

  /// The address or key is not a valid endpoint, or a request was about
  /// to leave the target's origin.
  invalidEndpoint,

  /// No connection is saved for this target on this account.
  notConnected,

  /// The address is the server this app already runs on.
  currentServer,

  /// The intent went stale: the app's account changed or the connection
  /// was removed while the call was in flight. Its answer is discarded.
  cancelled,

  /// The target answered something this build cannot read.
  malformed,
}

/// A connected installation could not be used, and why.
class ConnectionFailure extends StateError {
  ConnectionFailure(this.source, this.reason, {this.afterSend = false})
    : super('connection ${reason.name}');

  /// The target's origin; empty when the failure concerns this app's own
  /// account (a [ConnectionFailureReason.cancelled] intent).
  final String source;
  final ConnectionFailureReason reason;

  /// True when the request had already been sent: the business outcome is
  /// UNKNOWN, so the caller must not present it as refused and must not
  /// retry a mutation under a new identity.
  final bool afterSend;

  @override
  String toString() =>
      'ConnectionFailure(${reason.name}${afterSend ? ', after send' : ''})';
}

/// Which typed outcome [error] is, for [source]. Pure: reads the SDK's
/// types and status codes, never a localized sentence. Unknown errors are
/// [ConnectionFailureReason.malformed] — never "supported" or "authorized".
ConnectionFailure classifyConnectionError(
  Object error, {
  required String source,
  bool afterSend = false,
}) {
  ConnectionFailure as(ConnectionFailureReason reason) =>
      ConnectionFailure(source, reason, afterSend: afterSend);
  if (error is ConnectionFailure) return error;
  if (error is TimeoutException || isTransientNetworkFailure(error)) {
    return as(ConnectionFailureReason.unavailable);
  }
  if (error is AuthRetryableFetchException) {
    return as(ConnectionFailureReason.unavailable);
  }
  if (error is AuthException) {
    final status = int.tryParse(error.statusCode ?? '');
    final code = (error.code ?? '').toLowerCase();
    final message = error.message.toLowerCase();
    if (status != null && status >= 500) {
      return as(ConnectionFailureReason.unavailable);
    }
    if (code == 'invalid_credentials' ||
        code == 'user_banned' ||
        code == 'user_not_found' ||
        code == 'email_not_confirmed' ||
        status == 403 ||
        message.contains('invalid login credentials')) {
      return as(ConnectionFailureReason.denied);
    }
    // Everything else Auth says (expired session, refresh token not
    // found, reused or revoked) has the same recovery: sign in again.
    return as(ConnectionFailureReason.expired);
  }
  if (error is PostgrestException) {
    final code = error.code ?? '';
    final status = int.tryParse(code);
    if (code == 'PGRST301' || error.message.toLowerCase().contains('jwt')) {
      return as(ConnectionFailureReason.expired);
    }
    if (code == '42501' || status == 401 || status == 403) {
      return as(ConnectionFailureReason.denied);
    }
    if (status != null && status >= 500) {
      return as(ConnectionFailureReason.unavailable);
    }
    return as(ConnectionFailureReason.malformed);
  }
  if (error is StateError && error.message.contains('cross-origin')) {
    return as(ConnectionFailureReason.invalidEndpoint);
  }
  return as(ConnectionFailureReason.malformed);
}

/// What [client]'s server says about its public network interface (#1847),
/// read through the same pure reader the negotiator uses. A server from
/// before negotiation has no descriptor and is the supported baseline.
Future<PublicServerProfile> describeTarget(SupabaseClient client) async {
  try {
    final raw = await client
        .rpc<Object?>(PublicNetworkOperations.networkDescriptorRead.rpc!)
        .timeout(const Duration(seconds: 12));
    return readPublicDescriptor(raw);
  } on PostgrestException catch (e, st) {
    if (!isMissingFunction(e)) rethrow;
    TraceLogger.instance.log(
      TraceLevel.info,
      'connections',
      'no descriptor: pre-negotiation baseline',
      stackTrace: st,
    );
    return const PublicServerProfile.baseline();
  }
}

/// Whether a server described as [profile] can be connected from this
/// build. Pure. Whether each ACTION is available stays the negotiator's
/// per-operation decision; this only refuses a server nothing can use.
bool connectableProfile(PublicServerProfile profile) => switch (profile) {
  PublicBaselineServer() => true,
  PublicUnreadableServer() => false,
  PublicNegotiatingServer(:final protocolVersions) => protocolVersions.any(
    publicNetworkProtocolVersions.contains,
  ),
};
