// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1827 — where an assistant connects: the backend's own MCP function.
// Shared by the operator readiness checks (which compare the published
// resource with it) and the setup screen (which shows it to copy).
//
// #2145 — and what each assistant needs to add it: a command, a one-click
// link or a configuration entry, all built from the same connector URL.
import 'dart:convert';

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

/// #2145 — the name every snippet gives the server in the assistant's own
/// configuration: one word, so a command line needs no quoting.
const mcpServerName = 'deskilo';

/// #2145 — Claude's connector settings, where a custom connector is added
/// by URL (claude.ai on the web; Desktop and mobile share the same list).
final claudeConnectorsUri = Uri.parse('https://claude.ai/settings/connectors');

/// #2145 — Claude Code adds a remote server over Streamable HTTP; the
/// sign-in starts from `/mcp` in the session.
String claudeCodeAddCommand(Uri connector) =>
    'claude mcp add --transport http $mcpServerName $connector';

/// #2145 — Cursor's one-click install: the server configuration as
/// base64 JSON in `config`, percent-encoded so `+`, `/` and `=` survive
/// the query string.
Uri cursorInstallUri(Uri connector) {
  final config = base64.encode(utf8.encode(jsonEncode({'url': '$connector'})));
  return Uri.parse(
    'cursor://anysphere.cursor-deeplink/mcp/install'
    '?name=${Uri.encodeQueryComponent('DesKilo')}'
    '&config=${Uri.encodeQueryComponent(config)}',
  );
}

/// #2145 — VS Code's install link: the whole server entry as URL-encoded
/// JSON after `vscode:mcp/install?`.
Uri vscodeInstallUri(Uri connector) => Uri.parse(
  'vscode:mcp/install?${Uri.encodeComponent(jsonEncode({'name': mcpServerName, 'type': 'http', 'url': '$connector'}))}',
);

/// #2145 — the `mcpServers` entry most other clients read from a JSON file.
String genericMcpConfig(Uri connector) =>
    const JsonEncoder.withIndent('  ').convert({
      'mcpServers': {
        mcpServerName: {'type': 'http', 'url': '$connector'},
      },
    });

/// #2145 — for a client that only starts local servers: `mcp-remote`
/// bridges it to the remote endpoint and runs the sign-in in a browser.
String mcpRemoteCommand(Uri connector) => 'npx -y mcp-remote $connector';
