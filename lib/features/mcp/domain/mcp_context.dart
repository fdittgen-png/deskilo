// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1625 — an MCP management answer belongs to the context it was asked
// for. An answer that names another workspace or another confirmation is
// refused as a typed failure, never published as if it were the one
// requested: a late answer after a switch, or a server that mixes targets,
// must not fill the wrong screen.
//
// Three keys, never interchangeable. A workspace operation names its
// installation, account and workspace ([McpContextRef]); database
// eligibility and the administrators' queue name the installation and
// account only ([McpInstanceRef]), so they never follow the selected
// workspace; a native client is one verified installation, issuer,
// account and purpose ([McpTargetKey]). Display names are labels, never
// keys: the same UUID on two installations is two contexts.

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
);

/// What a native client is for. Each purpose is a separate client, so
/// disposing the confirmation client leaves management alone.
enum McpClientPurpose { management, confirmation }

/// Where a request goes: one installation, as one local account there.
sealed class McpScope {
  const McpScope();
  String get installationId;

  /// The target-local Auth UUID — not the canonical identity, not a
  /// workspace member id.
  String get account;
}

/// Database-level: eligibility, the administrators' queue, the person's
/// own connections. The selected workspace plays no part.
class McpInstanceRef extends McpScope {
  const McpInstanceRef({required this.installationId, required this.account});

  @override
  final String installationId;
  @override
  final String account;

  @override
  bool operator ==(Object other) =>
      other is McpInstanceRef &&
      other.installationId == installationId &&
      other.account == account;

  @override
  int get hashCode => Object.hash(McpInstanceRef, installationId, account);
}

/// A workspace operation: its installation, account and workspace.
/// Captured when the request is made; a retry reuses it, never the current
/// selection.
class McpContextRef extends McpScope {
  const McpContextRef({
    required this.installationId,
    required this.account,
    required this.workspaceId,
  });

  @override
  final String installationId;
  @override
  final String account;
  final String workspaceId;

  McpInstanceRef get instance =>
      McpInstanceRef(installationId: installationId, account: account);

  @override
  bool operator ==(Object other) =>
      other is McpContextRef &&
      other.installationId == installationId &&
      other.account == account &&
      other.workspaceId == workspaceId;

  @override
  int get hashCode =>
      Object.hash(McpContextRef, installationId, account, workspaceId);
}

/// One native client: verified installation + issuer + account + purpose.
class McpTargetKey {
  const McpTargetKey({
    required this.installationId,
    required this.issuer,
    required this.account,
    required this.purpose,
  });

  final String installationId;

  /// The installation's identity authority; empty where none is configured.
  final String issuer;
  final String account;
  final McpClientPurpose purpose;

  @override
  bool operator ==(Object other) =>
      other is McpTargetKey &&
      other.installationId == installationId &&
      other.issuer == issuer &&
      other.account == account &&
      other.purpose == purpose;

  @override
  int get hashCode => Object.hash(installationId, issuer, account, purpose);
}

/// An installation whose id the server itself answered for this account.
/// [source] is empty for the app's active backend, else the connected
/// origin it is reached through.
class VerifiedMcpTarget {
  VerifiedMcpTarget({
    required String installationId,
    required this.issuer,
    required this.account,
    this.source = '',
  }) : installationId = installationId.toLowerCase() {
    if (!_uuid.hasMatch(installationId) || account.isEmpty) {
      throw McpTargetUnverified(installationId);
    }
  }

  final String installationId;
  final String issuer;
  final String account;
  final String source;

  McpInstanceRef get instance =>
      McpInstanceRef(installationId: installationId, account: account);

  McpContextRef workspace(String workspaceId) => McpContextRef(
    installationId: installationId,
    account: account,
    workspaceId: workspaceId,
  );

  McpTargetKey key(McpClientPurpose purpose) => McpTargetKey(
    installationId: installationId,
    issuer: issuer,
    account: account,
    purpose: purpose,
  );

  @override
  bool operator ==(Object other) =>
      other is VerifiedMcpTarget &&
      other.installationId == installationId &&
      other.issuer == issuer &&
      other.account == account &&
      other.source == source;

  @override
  int get hashCode => Object.hash(installationId, issuer, account, source);
}

/// An answer that names a different [what] than the one asked for.
class McpProvenanceMismatch implements Exception {
  const McpProvenanceMismatch(this.what, this.expected, this.answered);

  final String what;
  final String expected;
  final String answered;

  @override
  String toString() =>
      'the answer is for $what $answered, not the $what $expected asked for';
}

/// No verified installation is registered for this scope: nothing is sent.
class McpTargetUnverified implements Exception {
  const McpTargetUnverified(this.installationId);
  final String installationId;

  @override
  String toString() => 'installation $installationId is not verified here';
}

/// The context was switched, signed out of or revoked while the request
/// was out. The answer is discarded, not published. A mutation may still
/// have been committed on its own server: this says nothing about that.
class McpContextSuperseded implements Exception {
  const McpContextSuperseded();

  @override
  String toString() => 'the context changed; the late answer was discarded';
}

/// The captured client no longer reaches the account and server it was
/// created for (the main app switched backend or account).
class McpTargetChanged implements Exception {
  const McpTargetChanged();

  @override
  String toString() => 'the target changed since the request was captured';
}

/// [value] when [answered] is the [expected] one; a typed refusal otherwise.
T requireProvenance<T>(
  T value, {
  required String what,
  required String expected,
  required String? answered,
}) {
  if (answered != expected) {
    throw McpProvenanceMismatch(what, expected, answered ?? '');
  }
  return value;
}
