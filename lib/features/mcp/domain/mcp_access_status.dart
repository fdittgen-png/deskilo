// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1625 — where one person stands with assistants on one workspace, as
// six separate facts rather than one "enabled" boolean. Identity and
// database eligibility belong to the installation (one each, however many
// workspaces); exposure, role and consent belong to the workspace. The
// server's answers decide every one; this only reads them side by side.
import '../../auth/domain/identity_binding.dart';
import 'mcp_admin.dart';
import 'mcp_connection.dart';
import 'mcp_context.dart';

enum McpIdentityState { verified, unlinked, unavailable }

/// Database eligibility. `revoked` covers an approval that lapsed or was
/// withdrawn: it has to be asked for again.
enum McpEligibilityState { notRequested, pending, approved, revoked, unavailable }

/// The workspace owner's policy.
enum McpExposureState { disabled, exposed, unavailable }

/// Whether the person's role leaves any exposed operation to offer.
enum McpRoleState { allowed, denied, unavailable }

/// Whether an assistant holds the person's consent for this workspace.
enum McpConsentState { missing, current, unavailable }

enum McpBackendState { available, unavailable, incompatible }

/// 0340 — assistants use the profile's Google sign-in and nothing else.
enum McpGoogleState {
  /// A Google identity, and this session was opened with it.
  ready,

  /// Google is linked, but this session used another way in.
  signInWithGoogle,

  /// The account has no Google identity: no assistant for it.
  linkGoogle,

  /// The server could not say.
  unavailable,
}

McpGoogleState mcpGoogleState(McpGoogleSignIn? google) =>
    switch ((google?.linked, google?.session)) {
      (true, true) => McpGoogleState.ready,
      (true, false) => McpGoogleState.signInWithGoogle,
      (false, _) => McpGoogleState.linkGoogle,
      _ => McpGoogleState.unavailable,
    };

/// The one thing that would move this person forward, and who does it.
enum McpNextStep {
  /// 0340 — the person links Google to the account (no Google: no MCP).
  linkGoogle,

  /// 0340 — the person signs in again, with Google.
  signInWithGoogle,

  /// The person links their account to the installation's identity.
  linkIdentity,

  /// The person asks this database's administrators.
  requestEligibility,

  /// A database administrator decides.
  awaitEligibility,

  /// The workspace owner exposes operations.
  ownerExposes,

  /// Nothing this person's role may offer here.
  roleDenied,

  /// The person connects an assistant for this workspace.
  consent,
  ready,

  /// The server could not be asked, or answered something unreadable.
  unavailable,
}

McpIdentityState mcpIdentityState(IdentityBindingStatus? identity) =>
    switch (identity?.state) {
      IdentityBindingState.verified => McpIdentityState.verified,
      IdentityBindingState.unlinked ||
      IdentityBindingState.ineligible ||
      IdentityBindingState.conflict => McpIdentityState.unlinked,
      _ => McpIdentityState.unavailable,
    };

McpEligibilityState mcpEligibilityState(DatabaseCapabilities? capabilities) =>
    switch (capabilities?.eligibility) {
      McpEligibility.eligible => McpEligibilityState.approved,
      McpEligibility.requested => McpEligibilityState.pending,
      McpEligibility.expired => McpEligibilityState.revoked,
      McpEligibility.notRequested ||
      McpEligibility.noIdentity => McpEligibilityState.notRequested,
      _ => McpEligibilityState.unavailable,
    };

McpBackendState mcpBackendState(
  IdentityBindingStatus? identity,
  DatabaseCapabilities? capabilities,
) => identity == null || capabilities == null
    ? McpBackendState.unavailable
    : capabilities.eligibility == McpEligibility.unavailable
    ? McpBackendState.incompatible
    : McpBackendState.available;

class McpAccessStatus {
  const McpAccessStatus({
    required this.context,
    this.google = McpGoogleState.ready,
    required this.identity,
    required this.eligibility,
    required this.exposure,
    required this.role,
    required this.consent,
    required this.backend,
  });

  final McpContextRef context;
  final McpGoogleState google;
  final McpIdentityState identity;
  final McpEligibilityState eligibility;
  final McpExposureState exposure;
  final McpRoleState role;
  final McpConsentState consent;
  final McpBackendState backend;

  /// Reads the server's answers for [context]. A missing answer is
  /// `unavailable`, never promoted to a permissive state.
  factory McpAccessStatus.derive(
    McpContextRef context, {
    McpGoogleSignIn? google,
    required IdentityBindingStatus? identity,
    required DatabaseCapabilities? capabilities,
    required McpPolicy? policy,
    required ConsentOptions? options,
    required List<McpConnectionInfo>? connections,
  }) {
    final ws = context.workspaceId;
    final forWs = policy != null && policy.workspaceId == ws ? policy : null;
    final offered = options?.workspaces.where((w) => w.id == ws).firstOrNull;
    // The policy is the owner's to read; a member learns exposure from
    // what the server offers them, which it only does when exposed.
    final exposure = forWs != null
        ? (forWs.featureEnabled && forWs.enabled && forWs.operations.isNotEmpty
              ? McpExposureState.exposed
              : McpExposureState.disabled)
        : offered != null && offered.operations.isNotEmpty
        ? McpExposureState.exposed
        : McpExposureState.unavailable;
    final role = options == null || !options.eligible
        ? McpRoleState.unavailable
        : offered != null && offered.operations.isNotEmpty
        ? McpRoleState.allowed
        : McpRoleState.denied;
    final consent = connections == null
        ? McpConsentState.unavailable
        : connections.any((c) => c.workspaces.any((w) => w.id == ws))
        ? McpConsentState.current
        : McpConsentState.missing;
    return McpAccessStatus(
      context: context,
      google: mcpGoogleState(google),
      identity: mcpIdentityState(identity),
      eligibility: mcpEligibilityState(capabilities),
      exposure: exposure,
      role: role,
      consent: consent,
      backend: mcpBackendState(identity, capabilities),
    );
  }

  /// The first unmet fact, in the order they depend on each other.
  McpNextStep get next {
    if (backend != McpBackendState.available) return McpNextStep.unavailable;
    // 0340 — Google first: without it nothing below can be used.
    if (google == McpGoogleState.linkGoogle) return McpNextStep.linkGoogle;
    if (google == McpGoogleState.signInWithGoogle) {
      return McpNextStep.signInWithGoogle;
    }
    if (google == McpGoogleState.unavailable) return McpNextStep.unavailable;
    if (identity == McpIdentityState.unavailable) return McpNextStep.unavailable;
    if (identity == McpIdentityState.unlinked) return McpNextStep.linkIdentity;
    switch (eligibility) {
      case McpEligibilityState.notRequested || McpEligibilityState.revoked:
        return McpNextStep.requestEligibility;
      case McpEligibilityState.pending:
        return McpNextStep.awaitEligibility;
      case McpEligibilityState.unavailable:
        return McpNextStep.unavailable;
      case McpEligibilityState.approved:
        break;
    }
    if (exposure == McpExposureState.unavailable) return McpNextStep.unavailable;
    if (exposure == McpExposureState.disabled) return McpNextStep.ownerExposes;
    if (role == McpRoleState.unavailable) return McpNextStep.unavailable;
    if (role == McpRoleState.denied) return McpNextStep.roleDenied;
    if (consent == McpConsentState.current) return McpNextStep.ready;
    return consent == McpConsentState.missing
        ? McpNextStep.consent
        : McpNextStep.unavailable;
  }
}

/// #1625 — the installation-level half, for the read-only overview of the
/// other installations this account connected: identity, eligibility and
/// the server, each read through that installation's own client. Nothing
/// here is a workspace fact, and nothing enables an action.
class McpInstanceStatus {
  const McpInstanceStatus({
    required this.source,
    required this.identity,
    required this.eligibility,
    required this.backend,
  });

  /// Nothing could be asked: an unverifiable record or a failing target.
  const McpInstanceStatus.unavailable(this.source)
    : identity = McpIdentityState.unavailable,
      eligibility = McpEligibilityState.unavailable,
      backend = McpBackendState.unavailable;

  factory McpInstanceStatus.derive(
    String source, {
    required IdentityBindingStatus? identity,
    required DatabaseCapabilities? capabilities,
  }) => McpInstanceStatus(
    source: source,
    identity: mcpIdentityState(identity),
    eligibility: mcpEligibilityState(capabilities),
    backend: mcpBackendState(identity, capabilities),
  );

  /// The connected origin — a label, never a key.
  final String source;
  final McpIdentityState identity;
  final McpEligibilityState eligibility;
  final McpBackendState backend;
}
