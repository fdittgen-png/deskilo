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
          'period': bad,
        })['period'], 'invalid_month', reason: bad);
      }
      // #2145 — always the caller's own: there is no member to name.
      expect(validateMcpInput(statement, {
        'workspace_id': '6b1d3f0e-0000-4000-8000-000000000002',
        'member_id': '6b1d3f0e-0000-4000-8000-000000000004',
        'period': '2026-09',
      })['member_id'], 'unknown_field');
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

  test('#1644 every output field is classified, and only operational ones leave by default', () {
    final contract = source();
    final classes = Map<String, dynamic>.from(contract['output_fields'] as Map);
    for (final entry in classes.entries) {
      final c = (entry.value as Map)['class'];
      expect(['operational', 'display', 'never'], contains(c), reason: '${entry.key} has class $c');
      expect('${(entry.value as Map)['purpose'] ?? ''}', isNotEmpty, reason: '${entry.key} needs a purpose');
    }
    for (final op in (contract['operations'] as List).cast<Map<String, dynamic>>()) {
      for (final f in op['output'] as List) {
        expect(classes, contains(f), reason: '${op['id']} emits $f, which no class covers');
      }
      final allowed = mcpAllowedOutput(contract, Map<String, dynamic>.from(op));
      for (final f in allowed) {
        expect((classes[f] as Map)['class'], 'operational', reason: '${op['id']} would let $f out');
      }
    }
    // The seat's label can name a person: never in an answer by default.
    final availability = (contract['operations'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((o) => o['id'] == 'get_availability');
    expect(mcpAllowedOutput(contract, Map<String, dynamic>.from(availability)), isNot(contains('name')));
  });

  test('#1645 optional disclosure is a finite list of display fields', () {
    final contract = source();
    final classes = Map<String, dynamic>.from(contract['output_fields'] as Map);
    for (final entry in classes.entries) {
      final field = entry.value as Map;
      if (!field.containsKey('disclosure')) continue;
      expect(field['disclosure'], 'optional', reason: '${entry.key}: the only disclosure is optional');
      expect(field['class'], 'display', reason: '${entry.key}: only a display label may be disclosed');
    }
    final ops = (contract['operations'] as List).cast<Map<String, dynamic>>();
    for (final op in ops) {
      final optional = mcpOptionalOutput(contract, op);
      expect(optional.toSet().intersection(mcpAllowedOutput(contract, op).toSet()), isEmpty,
          reason: '${op['id']}: an optional field is never sent by default');
      for (final f in optional) {
        expect(op['output'] as List, contains(f), reason: '${op['id']} does not emit $f');
      }
    }
    final availability = ops.firstWhere((o) => o['id'] == 'get_availability');
    expect(mcpOptionalOutput(contract, availability), ['name']);
    final reservations = ops.firstWhere((o) => o['id'] == 'list_my_reservations');
    expect(mcpOptionalOutput(contract, reservations), isEmpty);
  });

  test('the latest migration carries the generated catalogue verbatim', () {
    final migrations = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql') &&
            f.readAsStringSync().contains('function public.mcp_operation_catalogue()'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(migrations, isNotEmpty);
    expect(migrations.last.readAsStringSync(), contains(renderMcpCatalogueSql(source())),
        reason: '${migrations.last.path} does not carry the current catalogue: '
            'a contract change needs a migration with renderMcpCatalogueSql');
  });

  test('every dispatchable operation has its branch in mcp_execute_v1', () {
    final migrations = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.readAsStringSync().contains('function public.mcp_execute_v1('))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final body = migrations.last.readAsStringSync();
    // An operation needing native confirmation answers
    // `requires_confirmation` through the generic path and executes
    // nothing until #1619 consumes the confirmation.
    for (final op in mcpOperations.values.where((o) => o.dispatch && !o.nativeConfirmation)) {
      expect(body, contains("'${op.id}'"), reason: '${op.id} is dispatchable but has no branch');
      if (op.rpc != null) {
        expect(body, contains('public.${op.rpc}('), reason: '${op.id} never calls ${op.rpc}');
      }
    }
  });

  group('#1629 the OpenAPI document names only what exists', () {
    Map<String, dynamic> openapi() => jsonDecode(
        File('contracts/mcp/generated/openapi.json').readAsStringSync()) as Map<String, dynamic>;
    List<Map<String, dynamic>> nativeRpcs() => [
      for (final r in source()['native_rpcs'] as List) Map<String, dynamic>.from(r as Map),
    ];

    test('every documented RPC is in the replay with exactly these '
        'parameters, and a client may call it', () {
      final contract = File('assets/instance/contract.txt').readAsLinesSync();
      for (final r in nativeRpcs()) {
        final params = Map<String, dynamic>.from(r['params'] as Map);
        final signature = 'routine public.${r['rpc']}('
            '${[for (final e in params.entries) '${e.key} ${e.value}'].join(', ')}) ->';
        final line = contract.where((l) => l.startsWith(signature)).toList();
        expect(line, hasLength(1), reason: '${r['rpc']}: the replay has no `$signature`');
        expect(line.single, contains('exec:authenticated'), reason: '${r['rpc']}');
      }
    });

    test('one MCP endpoint, its metadata and the documented RPCs: no route '
        'per tool, no undocumented path', () {
      final paths = (openapi()['paths'] as Map).keys.cast<String>().toSet();
      expect(paths, {
        '/functions/v1/deskilo-mcp',
        '/functions/v1/deskilo-mcp/.well-known/oauth-protected-resource',
        for (final r in nativeRpcs()) '/rest/v1/rpc/${r['rpc']}',
      });
      for (final op in mcpOperations.values) {
        expect(paths.any((p) => p.endsWith('/${op.id}')), isFalse, reason: op.id);
      }
    });

    test('tools/call offers exactly the dispatchable tools', () {
      final post = ((openapi()['paths'] as Map)['/functions/v1/deskilo-mcp'] as Map)['post'] as Map;
      final schema = ((((post['requestBody'] as Map)['content'] as Map)['application/json'] as Map)['schema']) as Map;
      final names = (((schema['properties'] as Map)['params'] as Map)['properties'] as Map)['name'] as Map;
      expect((names['enum'] as List).toSet(), {
        for (final op in mcpOperations.values)
          if (op.dispatch) '${source()['tool_prefix']}${op.id}',
      });
    });

    test('every path is secured by a declared scheme, and administrators '
        'need the second factor', () {
      final doc = openapi();
      final schemes = ((doc['components'] as Map)['securitySchemes'] as Map).keys.toSet();
      for (final path in (doc['paths'] as Map).values) {
        for (final op in (path as Map).values) {
          for (final s in (op as Map)['security'] as List) {
            expect(schemes, containsAll((s as Map).keys), reason: '${op['operationId']}');
          }
        }
      }
      for (final r in nativeRpcs()) {
        if ((r['rpc'] as String).contains('eligibility') && r['rpc'] != 'request_mcp_eligibility' &&
            r['rpc'] != 'withdraw_mcp_eligibility') {
          expect(r['security'], 'administratorAal2', reason: '${r['rpc']}');
        }
      }
    });

    test('every documented answer is a valid envelope, and pending is not '
        'completed', () {
      final envelope = ((openapi()['components'] as Map)['schemas'] as Map)['McpEnvelope'] as Map;
      final properties = (envelope['properties'] as Map).keys.toSet();
      final statuses = (source()['statuses'] as List).toSet();
      for (final e in mcpDocumentedEnvelopes) {
        expect(properties, containsAll(e.keys), reason: '${e['status']}');
        expect(e.keys, containsAll(envelope['required'] as List), reason: '${e['status']}');
        expect(statuses, contains(e['status']));
        expect(mcpOperations.keys, contains(e['operation']));
      }
      expect({for (final e in mcpDocumentedEnvelopes) e['status']},
          containsAll(['denied', 'requires_confirmation', 'pending_validation', 'completed']));
      final pending = mcpDocumentedEnvelopes.firstWhere((e) => e['status'] == 'pending_validation');
      expect(pending['event_id'], isNotNull, reason: 'pending names the event it waits on');
    });
  });
}
