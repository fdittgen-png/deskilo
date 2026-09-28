// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1625 — an MCP management answer belongs to the context it was asked
// for. An answer that names another workspace or another confirmation is
// refused as a typed failure, never published as if it were the one
// requested: a late answer after a switch, or a server that mixes targets,
// must not fill the wrong screen.

/// The workspace (and, where known, the installation) a request is about.
/// Captured when the request is made; a retry reuses it, never the current
/// selection.
class McpContextRef {
  const McpContextRef({required this.workspaceId, this.installationId});

  final String workspaceId;
  final String? installationId;

  @override
  bool operator ==(Object other) =>
      other is McpContextRef &&
      other.workspaceId == workspaceId &&
      other.installationId == installationId;

  @override
  int get hashCode => Object.hash(workspaceId, installationId);
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
