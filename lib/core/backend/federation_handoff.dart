// SPDX-License-Identifier: AGPL-3.0-or-later

/// #1648 — the vocabulary of one "Continue with Deskilo" handoff.
///
/// Pure Dart: the flow reports these, the screen words them. Each failure
/// has its own next action; none of them is "create a local account".
enum FederationFailure {
  /// The browser returned a different person than this flow was for.
  wrongAccount,

  /// The Deskilo identity belongs to (or collides with) an existing account
  /// here that is not linked to it. Linking needs that account's own proof.
  unlinkedAccount,

  /// This server does not speak for the identity authority it advertised.
  incompatibleServer,

  /// Deskilo sign-in is not set up (or switched off) on this server.
  providerMissing,

  /// Nothing was judged: the network or the server did not answer.
  network,

  /// The provider or the person said no, or the flow was superseded.
  refused,

  /// The pending sign-in outlived its window; a fresh one is needed.
  expired,

  /// The system browser could not be opened.
  browserUnavailable,
}

/// The stages the app can truthfully claim. Idle is "no stage".
enum FederationStage { opening, waiting, completing }

/// One thing that happened to the flow [flow]: its callback was claimed
/// ([completing]), or it ended ([authenticated] or [failure]).
class FederationEvent {
  const FederationEvent.completing(this.flow)
    : completing = true,
      authenticated = false,
      failure = null;
  const FederationEvent.authenticated(this.flow)
    : completing = false,
      authenticated = true,
      failure = null;
  const FederationEvent.failed(this.flow, FederationFailure this.failure)
    : completing = false,
      authenticated = false;

  final String flow;
  final bool completing;
  final bool authenticated;
  final FederationFailure? failure;
}

/// Starting failed before any browser opened.
class FederationStartFailure implements Exception {
  const FederationStartFailure(this.failure);
  final FederationFailure failure;

  @override
  String toString() => 'FederationStartFailure($failure)';
}

/// Maps an Auth error CODE (never its prose) to the person's next action.
/// Codes as documented by Supabase Auth (`error_code` on a redirect,
/// `code` on an API error).
FederationFailure federationFailureFromCode(String? code) => switch (code) {
  'provider_disabled' ||
  'oauth_provider_not_supported' ||
  'manual_linking_disabled' => FederationFailure.providerMissing,
  'identity_already_exists' ||
  'email_exists' ||
  'user_already_exists' ||
  'email_conflict_identity_not_deletable' => FederationFailure.unlinkedAccount,
  'flow_state_expired' ||
  'flow_state_not_found' ||
  'bad_oauth_state' ||
  'bad_code_verifier' => FederationFailure.expired,
  'request_timeout' || 'unexpected_failure' => FederationFailure.network,
  _ => FederationFailure.refused,
};

/// What `finalize_identity_binding` (0269) answered, as a next action.
/// Null for a verified binding.
FederationFailure? federationFailureFromBinding(Object? binding) {
  if (binding is! Map) return FederationFailure.incompatibleServer;
  return switch ((binding['status'], binding['reason'])) {
    ('verified', _) => null,
    ('conflict', 'subject_bound_to_another_user') =>
      FederationFailure.unlinkedAccount,
    ('conflict', _) => FederationFailure.wrongAccount,
    ('unavailable', _) ||
    ('ineligible', 'issuer_mismatch') => FederationFailure.incompatibleServer,
    _ => FederationFailure.refused,
  };
}
