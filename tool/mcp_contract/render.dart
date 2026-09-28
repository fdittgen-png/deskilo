// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1609 — one operation contract, four renderings. `contracts/mcp/
// operations.json` is the only hand-written source; everything this
// returns is generated, committed, and compared by a drift test. The
// catalogue grants nothing: SQL stays the authority, and an operation
// appears as an MCP tool only once its handler exists (`handler: true`).
import 'dart:convert';

const generatedPaths = (
  tools: 'contracts/mcp/generated/tools.json',
  typescript: 'supabase/functions/_shared/mcp_contract.ts',
  dart: 'lib/core/mcp/mcp_operations.dart',
  openapi: 'contracts/mcp/generated/openapi.json',
  // #1629 — the same document, served beside the self-hosted Swagger UI.
  webOpenapi: 'web/api/openapi.json',
);

/// #1610/#1612 — the catalogue as the database reads it: the statement a
/// migration carries verbatim (see mcp_contract_test), so the dispatcher
/// and the policy validator ask the same source as every other rendering.
/// #1644 — what an operation may put in `data` by default: its declared
/// outputs that are classified `operational`, plus the envelope's own
/// always-allowed fields. Sorted, so every rendering agrees.
List<String> mcpAllowedOutput(Map<String, dynamic> contract, Map<String, dynamic> op) {
  final classes = Map<String, dynamic>.from(contract['output_fields'] as Map? ?? const {});
  bool operational(Object? f) => (classes['$f'] as Map?)?['class'] == 'operational';
  return {
    for (final f in op['output'] as List? ?? const []) if (operational(f)) '$f',
    for (final f in contract['always_output'] as List? ?? const []) if (operational(f)) '$f',
  }.toList()
    ..sort();
}

/// #1629 — the security schemes the documented paths use.
const Map<String, Object?> mcpSecuritySchemes = {
  'nativeSession': {
    'type': 'http',
    'scheme': 'bearer',
    'bearerFormat': 'JWT',
    'description': 'A signed-in Deskilo session on this installation.',
  },
  'administratorAal2': {
    'type': 'http',
    'scheme': 'bearer',
    'bearerFormat': 'JWT',
    'description': 'A database administrator\'s session at AAL2 (a second '
        'factor completed); aal1 is refused.',
  },
  'mcpOAuth': {
    'type': 'oauth2',
    'description': 'A resource-bound token from the installation\'s own '
        'OAuth server (authorization code with PKCE). Its scopes name the '
        'identity; they grant no business operation.',
    'flows': {
      'authorizationCode': {
        'authorizationUrl': '/auth/v1/oauth/authorize',
        'tokenUrl': '/auth/v1/oauth/token',
        'scopes': {
          'openid': 'Who is connecting',
          'email': 'The e-mail of that person',
          'profile': 'Their display name',
        },
      },
    },
  },
};

/// One tools/call answer, as the facade's McpEnvelope inside the MCP text
/// content — the envelope a parity test checks against McpEnvelope.
Map<String, Object?> mcpEnvelopeExample(
  String status, {
  Map<String, Object?>? data,
  String? eventId,
  String? errorCode,
}) => {
  'schema_version': 1,
  'request_id': '00000000-0000-4000-8000-000000000001',
  'operation': 'request_subscription_change',
  'workspace_id': '00000000-0000-4000-8000-0000000000a1',
  'status': status,
  'data': ?data,
  'event_id': ?eventId,
  if (errorCode != null) 'error': {'code': errorCode},
};

Map<String, Object?> _envelopeExample(Map<String, Object?> envelope) => {
  'summary': envelope['status'],
  'value': {
    'jsonrpc': '2.0',
    'id': 1,
    'result': {
      'content': [
        {'type': 'text', 'text': jsonEncode(envelope)},
      ],
    },
  },
};

/// #1629 — the answers the documentation shows: registered but not yet
/// approved, awaiting the app's confirmation, pending business validation,
/// and completed. Each is a real McpEnvelope.
final List<Map<String, Object?>> mcpDocumentedEnvelopes = [
  mcpEnvelopeExample('denied', errorCode: 'not_eligible'),
  mcpEnvelopeExample(
    'requires_confirmation',
    data: {
      'confirmation_id': '00000000-0000-4000-8000-0000000000c1',
      'expires_at': '2026-09-28T12:05:00Z',
    },
  ),
  mcpEnvelopeExample(
    'pending_validation',
    eventId: '00000000-0000-4000-8000-0000000000e1',
    data: {'member_id': '00000000-0000-4000-8000-0000000000d1'},
  ),
  mcpEnvelopeExample(
    'completed',
    data: {
      'member_id': '00000000-0000-4000-8000-0000000000d1',
      'subscription_pct': 50,
    },
  ),
];

String _sqlType(String t) => switch (t) {
  'uuid' => 'string',
  'text' => 'string',
  'boolean' => 'boolean',
  'integer' => 'integer',
  'jsonb' => 'object',
  'text[]' => 'array',
  _ => throw ArgumentError('unknown RPC parameter type $t'),
};

/// #1629 — the ACTUAL routes: one MCP endpoint and its metadata, then the
/// Supabase RPCs named in the contract's `native_rpcs`. Nothing else.
Map<String, Object?> mcpOpenApiPaths(Map<String, dynamic> contract) {
  final ops = [
    for (final o in contract['operations'] as List) Map<String, dynamic>.from(o as Map),
  ];
  final prefix = contract['tool_prefix'] as String? ?? '';
  final tools = [
    for (final op in ops)
      if (op['dispatch'] == true) '$prefix${op['id']}',
  ];
  final paths = <String, Object?>{
    '/functions/v1/deskilo-mcp': {
      'post': {
        'operationId': 'mcpJsonRpc',
        'summary': 'MCP over streamable HTTP: initialize, tools/list, tools/call',
        'security': [
          {'mcpOAuth': <String>[]},
        ],
        'requestBody': {
          'required': true,
          'content': {
            'application/json': {
              'schema': {
                'type': 'object',
                'required': ['jsonrpc', 'method'],
                'properties': {
                  'jsonrpc': {'const': '2.0'},
                  'id': {
                    'type': ['integer', 'string'],
                  },
                  'method': {
                    'enum': ['initialize', 'notifications/initialized', 'tools/list', 'tools/call'],
                  },
                  'params': {
                    'type': 'object',
                    'properties': {
                      'name': {'enum': tools},
                      'arguments': {'type': 'object'},
                    },
                  },
                },
              },
              'examples': {
                'toolsCall': {
                  'value': {
                    'jsonrpc': '2.0',
                    'id': 1,
                    'method': 'tools/call',
                    'params': {
                      'name': '${prefix}request_subscription_change',
                      'arguments': {
                        'workspace_id': '00000000-0000-4000-8000-0000000000a1',
                        'request_id': '00000000-0000-4000-8000-000000000001',
                      },
                    },
                  },
                },
              },
            },
          },
        },
        'responses': {
          '200': {
            'description': 'A JSON-RPC result; a tool answer is one McpEnvelope as text',
            'content': {
              'application/json': {
                'examples': {
                  for (final e in mcpDocumentedEnvelopes)
                    '${e['status']}': _envelopeExample(e),
                },
              },
            },
          },
          '401': {
            'description': 'No or invalid token; WWW-Authenticate names the '
                'protected-resource metadata',
          },
        },
      },
    },
    '/functions/v1/deskilo-mcp/.well-known/oauth-protected-resource': {
      'get': {
        'operationId': 'mcpResourceMetadata',
        'summary': 'OAuth protected-resource metadata (RFC 9728)',
        'security': <Object>[],
        'responses': {
          '200': {'description': 'The resource and its authorization server'},
        },
      },
    },
  };
  for (final raw in contract['native_rpcs'] as List? ?? const []) {
    final r = Map<String, dynamic>.from(raw as Map);
    final params = Map<String, dynamic>.from(r['params'] as Map);
    paths['/rest/v1/rpc/${r['rpc']}'] = {
      'post': {
        'operationId': r['rpc'],
        'summary': r['purpose'],
        'security': [
          {r['security']: <String>[]},
        ],
        'requestBody': {
          'required': params.isNotEmpty,
          'content': {
            'application/json': {
              'schema': {
                'type': 'object',
                'properties': {
                  for (final e in params.entries)
                    e.key: {
                      'type': _sqlType(e.value as String),
                      if (e.value == 'uuid') 'format': 'uuid',
                      'x-sql-type': e.value,
                    },
                },
              },
            },
          },
        },
        'responses': {
          '200': {'description': 'The RPC\'s jsonb answer'},
          '400': {'description': 'A refusal (PostgREST error body)'},
        },
      },
    };
  }
  return paths;
}

String renderMcpCatalogueSql(Map<String, dynamic> contract) {
  final ops = [
    for (final o in contract['operations'] as List) Map<String, dynamic>.from(o as Map),
  ];
  final catalogue = {
    'version': contract['version'],
    'operations': {
      for (final op in ops)
        op['id']: {
          'rpc': op['rpc'],
          'dispatch': op['dispatch'] == true,
          'authority': (op['authority'] as Map)['kind'],
          'permission': (op['authority'] as Map)['permission'],
          'features': op['features'],
          'scope': op['scope'],
          'mutation': op['mutation'],
          'confirmation': op['confirmation'],
          'output': mcpAllowedOutput(contract, op),
        },
    },
  };
  return '''create or replace function public.mcp_operation_catalogue()
returns jsonb
language sql
immutable
set search_path = public
as \$catalogue\$
  select \$json\$${jsonEncode(catalogue)}\$json\$::jsonb
\$catalogue\$;''';
}

const _header = 'GENERATED by `dart run tool/build_mcp_contract.dart` from '
    'contracts/mcp/operations.json (#1609). Do not edit.';

/// The JSON Schema of one typed field.
Map<String, Object?> fieldSchema(Map<String, dynamic> f) => switch (f['type']) {
      'uuid' => {'type': 'string', 'format': 'uuid'},
      'datetime' => {
          'type': 'string',
          'format': 'date-time',
          'pattern': r'(Z|[+-]\d{2}:\d{2})$',
        },
      'month' => {'type': 'string', 'pattern': r'^\d{4}-(0[1-9]|1[0-2])$'},
      'integer' => {
          'type': 'integer',
          if (f['min'] != null) 'minimum': f['min'],
          if (f['max'] != null) 'maximum': f['max'],
        },
      'boolean' => {'type': 'boolean'},
      'text' => {'type': 'string', 'maxLength': f['maxLength'] ?? 500},
      'enum' => {'type': 'string', 'enum': f['values']},
      final t => throw FormatException('unknown field type $t'),
    };

Map<String, Object?> inputSchema(Map<String, dynamic> op) {
  final input = Map<String, dynamic>.from(op['input'] as Map);
  return {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      for (final e in input.entries)
        e.key: fieldSchema(Map<String, dynamic>.from(e.value as Map)),
    },
    'required': [
      for (final e in input.entries)
        if ((e.value as Map)['required'] == true) e.key,
    ],
  };
}

Map<String, Object?> envelopeSchema(Map<String, dynamic> contract) => {
      'type': 'object',
      'additionalProperties': false,
      'required': ['schema_version', 'request_id', 'operation', 'status'],
      'properties': {
        'schema_version': {'const': contract['version']},
        'request_id': {'type': 'string', 'format': 'uuid'},
        'operation': {
          'enum': [for (final o in contract['operations'] as List) (o as Map)['id']],
        },
        'workspace_id': {'type': 'string', 'format': 'uuid'},
        'status': {'enum': contract['statuses']},
        'data': {'type': 'object'},
        'event_id': {'type': 'string', 'format': 'uuid'},
        'error': {
          'type': 'object',
          'properties': {
            'code': {'type': 'string'},
            'fields': {'type': 'object', 'additionalProperties': {'type': 'string'}},
          },
        },
      },
    };

String _pretty(Object? o) => '${const JsonEncoder.withIndent('  ').convert(o)}\n';

String _camel(String snake) {
  final parts = snake.split('_');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

/// Every generated file, by path.
Map<String, String> renderMcpContract(Map<String, dynamic> contract) {
  final ops = [
    for (final o in contract['operations'] as List) Map<String, dynamic>.from(o as Map),
  ];
  final prefix = contract['tool_prefix'] as String;

  final tools = {
    'x-generated': _header,
    'version': contract['version'],
    'tools': [
      for (final op in ops)
        if (op['handler'] == true)
          {
            'name': '$prefix${op['id']}',
            'description': op['description'],
            'inputSchema': inputSchema(op),
            'annotations': {
              'readOnlyHint': op['mutation'] == 'read',
              'idempotentHint': op['idempotency'] == 'request_id',
            },
          },
    ],
  };

  final ts = StringBuffer()
    ..writeln('// SPDX-License-Identifier: AGPL-3.0-or-later')
    ..writeln('// $_header')
    ..writeln()
    ..writeln('export const MCP_CONTRACT_VERSION = ${contract['version']};')
    ..writeln('export const MCP_TOOL_PREFIX = "$prefix";')
    ..writeln('export type McpStatus =')
    ..writeln('${[for (final s in contract['statuses'] as List) '  | "$s"'].join('\n')};')
    ..writeln('export type McpOperationId =')
    ..writeln('${[for (final op in ops) '  | "${op['id']}"'].join('\n')};')
    ..writeln()
    ..writeln('export interface McpEnvelope<T = Record<string, unknown>> {')
    ..writeln('  schema_version: ${contract['version']};')
    ..writeln('  request_id: string;')
    ..writeln('  operation: McpOperationId;')
    ..writeln('  workspace_id?: string;')
    ..writeln('  status: McpStatus;')
    ..writeln('  data?: T;')
    ..writeln('  event_id?: string;')
    ..writeln('  error?: { code: string; fields?: Record<string, string> };')
    ..writeln('}')
    ..writeln()
    ..writeln('export interface McpOperation {')
    ..writeln('  id: McpOperationId;')
    ..writeln('  rpc: string | null;')
    ..writeln('  handler: boolean;')
    ..writeln('  dispatch: boolean;')
    ..writeln('  authority: { kind: "self" | "member" | "permission"; permission?: string };')
    ..writeln('  features: string[];')
    ..writeln('  scope: "discovery" | "own" | "workspace";')
    ..writeln('  mutation: "read" | "write" | "request" | "decision";')
    ..writeln('  idempotency: "none" | "request_id";')
    ..writeln('  confirmation: "none" | "native";')
    ..writeln('  params: Record<string, string>;')
    ..writeln('  fixed: Record<string, unknown>;')
    ..writeln('  output: string[];')
    ..writeln('}')
    ..writeln()
    ..writeln('export const MCP_OPERATIONS: Record<McpOperationId, McpOperation> = {');
  for (final op in ops) {
    final input = Map<String, dynamic>.from(op['input'] as Map);
    final params = {
      for (final e in input.entries)
        if ((e.value as Map)['param'] != null) e.key: (e.value as Map)['param'],
    };
    ts.writeln('  ${op['id']}: ${jsonEncode({
      'id': op['id'],
      'rpc': op['rpc'],
      'handler': op['handler'] == true,
      'dispatch': op['dispatch'] == true,
      'authority': op['authority'],
      'features': op['features'],
      'scope': op['scope'],
      'mutation': op['mutation'],
      'idempotency': op['idempotency'],
      'confirmation': op['confirmation'],
      'params': params,
      'fixed': op['fixed'] ?? const <String, Object?>{},
      'output': op['output'],
    })},');
  }
  ts
    ..writeln('};')
    ..writeln()
    ..writeln('export const MCP_INPUT_SCHEMAS: Record<McpOperationId, unknown> = {');
  for (final op in ops) {
    ts.writeln('  ${op['id']}: ${jsonEncode(inputSchema(op))},');
  }
  ts
    ..writeln('};')
    ..writeln()
    ..writeln('/** #1644 — what each operation may return in `data` by default. */')
    ..writeln('export const MCP_OUTPUT_ALLOWED: Record<McpOperationId, readonly string[]> = {');
  for (final op in ops) {
    ts.writeln('  ${op['id']}: ${jsonEncode(mcpAllowedOutput(contract, op))},');
  }
  ts
    ..writeln('};')
    ..writeln()
    ..writeln('export const MCP_FORBIDDEN_INPUTS: readonly string[] = ${jsonEncode(contract['forbidden_inputs'])};');

  final dart = StringBuffer()
    ..writeln('// SPDX-License-Identifier: AGPL-3.0-or-later')
    ..writeln('//')
    ..writeln('// $_header')
    ..writeln('// ignore_for_file: lines_longer_than_80_chars')
    ..writeln()
    ..writeln("import 'mcp_spec.dart';")
    ..writeln()
    ..writeln('/// The contract version these specs were generated from.')
    ..writeln('const int mcpContractVersion = ${contract['version']};')
    ..writeln()
    ..writeln('/// Names no input may carry: identity, role, SQL, targets, approval state.')
    ..writeln('const Set<String> mcpForbiddenInputs = {')
    ..writeln([for (final f in contract['forbidden_inputs'] as List) "  '$f',"].join('\n'))
    ..writeln('};')
    ..writeln()
    ..writeln('/// Every catalogued operation, handler or not.')
    ..writeln('const Map<String, McpOperationSpec> mcpOperations = {');
  for (final op in ops) {
    final input = Map<String, dynamic>.from(op['input'] as Map);
    final authority = Map<String, dynamic>.from(op['authority'] as Map);
    dart.writeln("  '${op['id']}': McpOperationSpec(");
    dart.writeln("    id: '${op['id']}',");
    dart.writeln('    rpc: ${op['rpc'] == null ? 'null' : "'${op['rpc']}'"},');
    dart.writeln('    handler: ${op['handler'] == true},');
    dart.writeln('    dispatch: ${op['dispatch'] == true},');
    dart.writeln('    authority: McpAuthority.${authority['kind']},');
    dart.writeln('    permission: ${authority['permission'] == null ? 'null' : "'${authority['permission']}'"},');
    dart.writeln('    features: [${[for (final f in op['features'] as List) "'$f'"].join(', ')}],');
    dart.writeln('    scope: McpScope.${op['scope']},');
    dart.writeln('    mutation: McpMutation.${op['mutation']},');
    dart.writeln('    idempotent: ${op['idempotency'] == 'request_id'},');
    dart.writeln('    nativeConfirmation: ${op['confirmation'] == 'native'},');
    dart.writeln('    fields: {');
    for (final e in input.entries) {
      final f = Map<String, dynamic>.from(e.value as Map);
      final type = f['type'] == 'enum' ? 'enum_' : _camel(f['type'] as String);
      dart.writeln("      '${e.key}': McpField(McpFieldType.$type"
          "${f['required'] == true ? ', required: true' : ''}"
          "${f['min'] != null ? ', min: ${f['min']}' : ''}"
          "${f['max'] != null ? ', max: ${f['max']}' : ''}"
          "${f['maxLength'] != null ? ', maxLength: ${f['maxLength']}' : ''}"
          "${f['values'] != null ? ', values: [${[for (final v in f['values'] as List) "'$v'"].join(', ')}]' : ''}"
          "${f['param'] != null ? ", param: '${f['param']}'" : ''}),");
    }
    dart.writeln('    },');
    dart.writeln('    output: [${[for (final o in op['output'] as List) "'$o'"].join(', ')}],');
    dart.writeln('  ),');
  }
  dart.writeln('};');

  final openapi = {
    'x-generated': _header,
    'openapi': '3.1.0',
    'info': {
      'title': 'Deskilo MCP operation payloads',
      'version': '${contract['version']}',
      'description': 'MCP is JSON-RPC over ONE HTTP endpoint '
          '(/functions/v1/deskilo-mcp): initialize, tools/list and tools/call. '
          'There is no route per tool. The REST paths below are the actual '
          'Supabase RPCs behind it and the native management RPCs the app '
          'calls. OAuth identity scopes are not business grants: the facade '
          're-checks the live role, the workspace policy, database '
          'eligibility and, for writes, a confirmation in the Deskilo app.',
    },
    'servers': [
      {
        'url': '{supabase_url}',
        'variables': {
          'supabase_url': {'default': 'https://your-project.supabase.co'},
        },
      },
    ],
    'paths': mcpOpenApiPaths(contract),
    'components': {
      'securitySchemes': mcpSecuritySchemes,
      'schemas': {
        'McpEnvelope': envelopeSchema(contract),
        for (final op in ops)
          '${_camel(op['id'] as String)[0].toUpperCase()}${_camel(op['id'] as String).substring(1)}Input': {
            ...inputSchema(op),
            'x-operation': op['id'],
            'x-rpc': op['rpc'],
            'x-handler': op['handler'] == true,
          },
      },
    },
  };

  return {
    generatedPaths.tools: _pretty(tools),
    generatedPaths.typescript: ts.toString(),
    generatedPaths.dart: dart.toString(),
    generatedPaths.openapi: _pretty(openapi),
    generatedPaths.webOpenapi: _pretty(openapi),
  };
}
