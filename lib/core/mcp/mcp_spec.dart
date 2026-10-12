// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1609 — the shapes the generated operation catalogue
// (`mcp_operations.dart`) is written in, and the one input validator every
// MCP adapter uses. The catalogue grants nothing: SQL decides who may do
// what; this refuses malformed or identity-bearing input before it gets
// that far.

enum McpAuthority { self, member, permission }

enum McpScope { discovery, own, workspace }

enum McpMutation { read, write, request, decision }

enum McpFieldType { uuid, datetime, month, integer, boolean, text, enum_ }

class McpField {
  const McpField(
    this.type, {
    this.required = false,
    this.min,
    this.max,
    this.maxLength,
    this.values = const [],
    this.param,
  });

  final McpFieldType type;
  final bool required;
  final int? min, max, maxLength;
  final List<String> values;

  /// The RPC parameter this field fills, when the operation has one.
  final String? param;
}

class McpOperationSpec {
  const McpOperationSpec({
    required this.id,
    required this.rpc,
    required this.handler,
    required this.dispatch,
    required this.authority,
    required this.permission,
    required this.features,
    required this.scope,
    required this.mutation,
    required this.idempotent,
    required this.nativeConfirmation,
    required this.fields,
    required this.output,
    required this.group,
  });

  final String id;

  /// The existing Supabase RPC this operation binds to; null while the
  /// read has no RPC of its own.
  final String? rpc;

  /// Whether an MCP handler exists. Only these may be advertised.
  final bool handler;

  /// #1612 — whether `mcp_execute_v1` implements it. Only these may be
  /// named in a workspace policy.
  final bool dispatch;
  final McpAuthority authority;
  final String? permission;
  final List<String> features;
  final McpScope scope;
  final McpMutation mutation;
  final bool idempotent;
  final bool nativeConfirmation;
  final Map<String, McpField> fields;
  final List<String> output;

  /// #2391 — the process group the policy screen shows the operation in,
  /// from the contract (`mcpOperationGroupOf`), never a hand-kept list.
  final String group;
}
