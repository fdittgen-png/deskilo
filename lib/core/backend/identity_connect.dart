// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1834 A / #2562 C1b -- connecting another installation with the identity
// the person already has, as screens see it: the intent kept while the
// browser is open, the readiness checked before it opens, and the outcome.
// [SecondaryFederation] (secondary_federation.dart) runs it against real
// servers; tests and Demo answer [IdentityConnector] in memory.
import 'backend_settings.dart';
import 'connection_outcome.dart';
import 'federation_authority.dart';
import 'federation_handoff.dart';

/// What the person was about to do on the other server. Kept while the
/// browser is open, so the screen resumes exactly that — with its normal
/// confirmation — and never anything else.
enum SecondaryConnectAction {
  contact,
  inquiry,
  apply,

  /// #2562 C1b -- open a space of a linked server whose sign-in ended.
  enter,
}

class SecondaryConnectIntent {
  const SecondaryConnectIntent({
    required this.target,
    required this.workspaceId,
    required this.action,
  });

  /// The other server, as its public card names it.
  final BackendEndpoint target;
  final String workspaceId;
  final SecondaryConnectAction action;
}

/// Who the person is at the identity authority.
class CanonicalIdentity {
  const CanonicalIdentity(this.issuer, this.subject);
  final String issuer;
  final String subject;
}

/// Why connecting with the identity is not possible for this target.
/// Each is a named answer; none of them creates an account anywhere.
enum IdentityConnectUnsupported {
  /// This app's own server does not tell who the person is at an
  /// authority another server could accept.
  noSharedIdentity,

  /// The other server does not offer "Continue with Deskilo".
  targetWithoutDeskiloSignIn,

  /// The other server accepts a DIFFERENT identity authority.
  differentAuthority,

  /// The other server speaks no connection protocol this build speaks.
  serverUnsupported,

  /// The other server is this app's own server.
  currentServer,

  /// Nothing answered.
  unavailable,
}

class IdentityConnectUnavailable implements Exception {
  const IdentityConnectUnavailable(this.reason);
  final IdentityConnectUnsupported reason;

  @override
  String toString() => 'IdentityConnectUnavailable(${reason.name})';
}

/// The other server checked before anything opens: its address, the
/// identity authority it accepts and the installation it is.
class IdentityConnectReadiness {
  const IdentityConnectReadiness({
    required this.target,
    required this.authority,
    required this.identity,
  });
  final BackendEndpoint target;
  final FederationAuthority authority;
  final CanonicalIdentity identity;

  /// The host the person is about to sign in to.
  String get host => Uri.parse(target.url).host;
}

enum SecondaryConnectStatus {
  /// Bound on the other server and saved in the connection registry.
  connected,

  /// Nothing was saved; [SecondaryConnectEvent.failure] says why.
  failed,

  /// The other server accepted the person, but this device could not keep
  /// the connection. Nothing was submitted; connecting again is safe.
  notSaved,

  /// The person (or a newer flow) gave up before the browser returned.
  cancelled,
}

class SecondaryConnectEvent {
  const SecondaryConnectEvent(
    this.flow,
    this.intent,
    this.status, {
    this.failure,
    this.notSaved,
  });
  final String flow;
  final SecondaryConnectIntent intent;
  final SecondaryConnectStatus status;
  final FederationFailure? failure;
  final ConnectionFailure? notSaved;
}

/// The connection journey as screens see it. [SecondaryFederation] runs
/// it against real servers; tests and Demo answer it in memory.
abstract interface class IdentityConnector {
  /// Checks the other server without launching anything.
  Future<IdentityConnectReadiness> assess(BackendEndpoint target);

  /// Opens the other server's own sign-in ONCE; answers the flow id. The
  /// outcome arrives later on [events].
  Future<String> begin(SecondaryConnectIntent intent);

  /// Abandons [flow] if its browser has not come back yet.
  Future<void> cancel(String flow);

  Stream<SecondaryConnectEvent> get events;
}
