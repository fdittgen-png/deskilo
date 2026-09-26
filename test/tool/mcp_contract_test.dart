// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1609 — the MCP operation contract is one source and four generated
// renderings. The renderings are what the generator writes (drift), every
// RPC a descriptor binds to exists in the replayed schema with the named
// parameters and is executable by `authenticated`, every permission and
// feature it names exists, nothing without a handler is advertised, and
// the input validator refuses identity spoofing, malformed ids, months,
// offset-less timestamps and unknown fields while accepting the app's own
// payload shapes.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/mcp/mcp_operations.dart';
import 'package:deskilo/core/mcp/mcp_spec.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/mcp_contract/render.dart';

Map<String, dynamic> source() => jsonDecode(
    File('contracts/mcp/operations.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('every committed rendering is what the generator writes', () {
    final rendered = renderMcpContract(source());
    for (final entry in rendered.entries) {
      expect(File(entry.key).readAsStringSync(), entry.value,
          reason: '${entry.key} is stale: run `dart run tool/build_mcp_contract.dart`');
    }
    expect(renderMcpContract(source()), rendered, reason: 'deterministic');
  });

  test('the fixed catalogue: nineteen operations, one prefix, no duplicates', () {
    final ids = [for (final o in source()['operations'] as List) (o as Map)['id']];
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, hasLength(19));
    expect(source()['tool_prefix'], 'deskilo_');
    expect(mcpOperations.keys.toList(), ids);
  });

  test('every bound RPC exists, takes the named parameters, and a client may call it', () {
    final contract = File('assets/instance/contract.txt').readAsLinesSync();
    for (final op in mcpOperations.values) {
      final rpc = op.rpc;
      if (rpc == null) continue;
      final line = contract.where((l) => l.startsWith('routine public.$rpc(')).toList();
      expect(line, hasLength(1), reason: '${op.id} binds $rpc, which the replay does not have (or has twice)');
      expect(line.single, contains('exec:authenticated'), reason: '$rpc is not callable by a client');
      for (final f in op.fields.values) {
        if (f.param != null) {
          expect(line.single, contains('${f.param} '), reason: '${op.id}: $rpc has no ${f.param}');
        }
      }
    }
  });

  test('every permission and feature named exists; the catalogue grants nothing', () {
    final permissions = {for (final p in WorkspacePermission.values) p.name};
    final features = {for (final f in WorkspaceFeature.values) f.name};
    for (final op in mcpOperations.values) {
      if (op.authority == McpAuthority.permission) {
        expect(permissions, contains(op.permission), reason: op.id);
      } else {
        expect(op.permission, isNull, reason: op.id);
      }
      for (final f in op.features) {
        expect(features, contains(f), reason: '${op.id}: $f');
      }
      if (op.scope != McpScope.discovery) {
        expect(op.fields['workspace_id']?.required, isTrue,
            reason: '${op.id}: every business call names its workspace');
      }
      if (op.mutation != McpMutation.read) {
        expect(op.idempotent, isTrue, reason: '${op.id} mutates without a request id');
        expect(op.fields['request_id']?.required, isTrue, reason: op.id);
      }
    }
  });

  test('nothing without a handler is advertised', () {
    final tools = (jsonDecode(File(generatedPaths.tools).readAsStringSync()) as Map)['tools'] as List;
    final handled = mcpOperations.values.where((o) => o.handler).map((o) => 'deskilo_${o.id}');
    expect([for (final t in tools) (t as Map)['name']], handled.toList());
  });

  group('input validation', () {
    final create = mcpOperations['create_reservation']!;
    Map<String, Object?> valid() => {
          'request_id': '6b1d3f0e-0000-4000-8000-000000000001',
          'workspace_id': '6b1d3f0e-0000-4000-8000-000000000002',
          'seat_id': '6b1d3f0e-0000-4000-8000-000000000003',
          'starts_at': '2026-10-01T08:00:00+02:00',
          'ends_at': '2026-10-01T12:00:00Z',
        };

    test('the app\'s own shape is accepted', () {
      expect(validateMcpInput(create, valid(), forbidden: mcpForbiddenInputs), isEmpty);
    });

    test('identity and authority fields are refused by name', () {
      for (final field in ['user_id', 'actor', 'role', 'approved', 'sql']) {
        final errors = validateMcpInput(create, {...valid(), field: 'x'},
            forbidden: mcpForbiddenInputs);
        expect(errors[field], 'forbidden', reason: field);
      }
    });

    test('malformed values each name their field', () {
      expect(validateMcpInput(create, {...valid(), 'workspace_id': 'not-a-uuid'})['workspace_id'],
          'invalid_uuid');
      expect(validateMcpInput(create, {...valid(), 'starts_at': '2026-10-01T08:00:00'})['starts_at'],
          'invalid_datetime', reason: 'no offset: the server owns the zone');
      expect(validateMcpInput(create, {...valid(), 'extra': 1})['extra'], 'unknown_field');
      expect(validateMcpInput(create, {...valid()}..remove('request_id'))['request_id'], 'required');
      final statement = mcpOperations['get_my_statement']!;
      for (final bad in ['2026-13', '2026-1', '26-01', '2026-00']) {
        expect(validateMcpInput(statement, {
          'workspace_id': '6b1d3f0e-0000-4000-8000-000000000002',
          'member_id': '6b1d3f0e-0000-4000-8000-000000000004',
          'period': bad,
        })['period'], 'invalid_month', reason: bad);
      }
      final pct = mcpOperations['request_subscription_change']!;
      expect(validateMcpInput(pct, {
        'request_id': '6b1d3f0e-0000-4000-8000-000000000001',
        'workspace_id': '6b1d3f0e-0000-4000-8000-000000000002',
        'member_id': '6b1d3f0e-0000-4000-8000-000000000004',
        'pct': 101,
      })['pct'], 'too_large');
      final status = mcpOperations['request_member_status_change']!;
      expect(validateMcpInput(status, {
        'request_id': '6b1d3f0e-0000-4000-8000-000000000001',
        'workspace_id': '6b1d3f0e-0000-4000-8000-000000000002',
        'member_id': '6b1d3f0e-0000-4000-8000-000000000004',
        'status': 'owner',
      })['status'], 'invalid_value');
    });
  });
}
