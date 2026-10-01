// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1827 — where an assistant connects: the backend's own MCP function.
// Shared by the operator readiness checks (which compare the published
// resource with it) and the setup screen (which shows it to copy).

/// The Edge Function that serves MCP on every installation.
const mcpEndpointSlug = 'deskilo-mcp';

/// The connector URL for the backend at [backendUrl], or null when the
/// process runs without one (Demo, tests) or it is not an http(s) URL.
Uri? mcpConnectorUri(String backendUrl) {
  final base = Uri.tryParse(backendUrl.trim());
  if (base == null || !base.hasAuthority) return null;
  if (base.scheme != 'https' && base.scheme != 'http') return null;
  final path = base.path.replaceAll(RegExp(r'/+$'), '');
  return base.replace(path: '$path/functions/v1/$mcpEndpointSlug');
}
