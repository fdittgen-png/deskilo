// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2504 — one WebMCP tool as the MCP contract describes it. The list of
// these (`webmcp_tools.g.dart`) is generated from
// `contracts/mcp/operations.json`; nothing here grants anything.

/// A tool the web app may offer to an in-browser agent. [inputSchema] is the
/// contract's JSON schema, kept as the exact text the generator wrote.
class WebMcpToolSpec {
  const WebMcpToolSpec({
    required this.id,
    required this.name,
    required this.title,
    required this.description,
    required this.inputSchema,
    required this.mutation,
    required this.confirmation,
    required this.scope,
    required this.features,
    required this.readOnly,
    required this.destructive,
  });

  /// The contract's operation id, e.g. `create_reservation`.
  final String id;

  /// The tool name an agent calls, e.g. `deskilo_create_reservation`.
  final String name;
  final String title;
  final String description;

  /// JSON text of the contract's input schema.
  final String inputSchema;

  /// `read`, `write`, `request` or `decision`.
  final String mutation;

  /// `none` or `native`.
  final String confirmation;

  /// `discovery`, `own` or `workspace`.
  final String scope;

  /// Workspace feature keys that must all be effective for the tool.
  final List<String> features;
  final bool readOnly;
  final bool destructive;
}
