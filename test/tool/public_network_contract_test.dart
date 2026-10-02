// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1847 — the public network contract is one hand-written catalogue and
// three generated renderings. The renderings are what the generator writes
// (drift); every binding is what the replayed database grants (anonymous
// reads only of granted columns, management and participant RPCs never
// executable by anon, the owner's input allow-list equal to the SQL's); the
// external and internal documents are separate; every operation names a
// real consumer that uses it and tests that exist; and the binding check
// is proved able to fail on a deliberately incompatible change.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/public_network/public_network_operations.dart';
import 'package:deskilo/core/public_network/public_network_spec.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract_common/primitives.dart';
import '../../tool/public_network_contract/check.dart';
import '../../tool/public_network_contract/render.dart';

const _source = 'contracts/public_network/operations.json';
const _pgtap = 'supabase/tests/database/105_public_network_boundary.sql';

Map<String, dynamic> source() =>
    jsonDecode(File(_source).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> ops(Map<String, dynamic> c) => [
  for (final o in c['operations'] as List) Map<String, dynamic>.from(o as Map),
];

List<String> routines() =>
    File('assets/instance/contract.txt')
        .readAsLinesSync()
        .where((l) => l.startsWith('routine '))
        .toList();

Map<String, String> migrations() => {
  for (final f in Directory('supabase/migrations').listSync().whereType<File>())
    if (f.path.endsWith('.sql')) f.uri.pathSegments.last: f.readAsStringSync(),
};

List<String> problems(Map<String, dynamic> c) => publicNetworkBindingProblems(
  c,
  routines: routines(),
  migrations: migrations(),
);

Map<String, dynamic> openapi(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('every committed rendering is what the generator writes', () {
    final rendered = renderPublicNetworkContract(source());
    for (final entry in rendered.entries) {
      expect(
        File(entry.key).readAsStringSync(),
        entry.value,
        reason:
            '${entry.key} is stale: run '
            '`dart run tool/build_public_network_contract.dart`',
      );
    }
    expect(
      renderPublicNetworkContract(source()),
      rendered,
      reason: 'deterministic',
    );
  });

  // 7→8 (2026-10-02): #2086 publication.page.reset.
  test('the current catalogue: eight operations with stable, unique ids, '
      'and the generated adapter carries each', () {
    final ids = [for (final op in ops(source())) op['id'] as String];
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, hasLength(8));
    for (final id in ids) {
      expect(id, matches(RegExp(r'^[a-z]+(\.[a-z_]+)+$')), reason: id);
    }
    expect(publicNetworkOperations.keys.toList(), ids);
    expect(publicNetworkProtocolVersion, source()['version']);
  });

  test('every binding is what the replayed database grants', () {
    expect(problems(source()), isEmpty);
  });

  group('the binding check fails on a deliberately incompatible change', () {
    Map<String, dynamic> mutate(void Function(Map<String, dynamic> c) f) {
      final c = source();
      f(c);
      return c;
    }

    Map<String, dynamic> op(Map<String, dynamic> c, String id) =>
        (c['operations'] as List).cast<Map<String, dynamic>>().firstWhere(
          (o) => o['id'] == id,
        );

    test('a column anonymous readers are not granted', () {
      final c = mutate(
        (c) =>
            ((op(c, 'directory.workspaces.search')['binding'] as Map)['select']
                    as List)
                .add('company_id'),
      );
      expect(problems(c), [contains('company_id is not granted to anon')]);
    });

    test('a management operation declared anonymous', () {
      final c = mutate(
        (c) => op(c, 'publication.page.save')['principal'] = 'anonymous',
      );
      expect(problems(c), [contains('only the public surface is anonymous')]);
    });

    test('a management operation without the owner', () {
      final c = mutate(
        (c) => op(c, 'publication.page.read')['authority'] = 'self',
      );
      expect(problems(c), [contains('management requires the owner')]);
    });

    test('an input key the server does not accept', () {
      final c = mutate(
        (c) =>
            (((c['schemas'] as Map)['PublicationInput'] as Map)['fields']
                as Map)['internal_note'] = {
              'type': 'text',
            },
      );
      expect(problems(c), [contains('internal_note')]);
    });

    test('a parameter the RPC does not have', () {
      final c = mutate(
        (c) =>
            ((op(c, 'workspace.profile.request')['binding'] as Map)['params']
                    as Map)['p_role'] =
                'text',
      );
      expect(problems(c), [contains('no parameter p_role text')]);
    });

    test('an RPC executable by anon', () {
      final anonymous = [
        for (final l in routines())
          l.startsWith('routine public.save_workspace_public_page(')
              ? l.replaceFirst('exec:authenticated', 'exec:anon,authenticated')
              : l,
      ];
      expect(
        publicNetworkBindingProblems(
          source(),
          routines: anonymous,
          migrations: migrations(),
        ),
        [contains('executable by anon')],
      );
    });
  });

  test('the external and internal documents are separate OpenAPI 3.1 '
      'documents, and together name every operation once', () {
    final external = openapi(publicNetworkGeneratedPaths.external);
    final internal = openapi(publicNetworkGeneratedPaths.internal);
    Set<String> named(Map<String, dynamic> doc) => {
      for (final path in (doc['paths'] as Map).values)
        for (final o in (path as Map).values) ...[
          if ((o as Map)['x-deskilo-operation'] != null)
            o['x-deskilo-operation'] as String,
          ...((o['x-deskilo-variants'] as Map?)?.keys.cast<String>() ??
              const <String>[]),
        ],
    };
    expect(external['openapi'], '3.1.0');
    expect(internal['openapi'], '3.1.0');
    final ext = named(external), intl = named(internal);
    expect(ext.intersection(intl), isEmpty);
    expect(ext.union(intl), {for (final op in ops(source())) op['id']});
    for (final op in ops(source())) {
      expect(
        (op['surface'] == 'management' ? intl : ext).contains(op['id']),
        isTrue,
        reason: '${op['id']} is documented on the wrong side',
      );
    }
    expect(
      jsonEncode(external),
      isNot(contains('save_workspace_public_page')),
      reason: 'management never appears in the external document',
    );
  });

  test(
    'every operation names a consumer that uses it and tests that exist',
    () {
      for (final op in ops(source())) {
        final constant =
            'PublicNetworkOperations.${camelCase(op['id'] as String)}';
        final binding = op['binding'] as Map;
        for (final path in op['consumers'] as List) {
          final text = File(path as String).readAsStringSync();
          expect(
            text.contains(constant) ||
                text.contains(camelCase(op['id'] as String)),
            isTrue,
            reason: '$path does not use $constant',
          );
        }
        expect(op['tests'] as List, isNotEmpty, reason: '${op['id']}');
        for (final path in op['tests'] as List) {
          final text = File(path as String).readAsStringSync();
          final names = [
            constant,
            ?binding['rpc'] as String?,
            ?binding['relation'] as String?,
            ?(op['output'] as Map)['schema'] as String?,
          ];
          expect(
            names.any(text.contains),
            isTrue,
            reason: '$path does not exercise ${op['id']}',
          );
        }
      }
    },
  );

  test('every feature an operation names exists', () {
    final features = {for (final f in WorkspaceFeature.values) f.name};
    for (final op in publicNetworkOperations.values) {
      for (final f in op.features) {
        expect(features, contains(f), reason: '${op.id}: $f');
      }
    }
  });

  test('the database test pins the same public document allow-list', () {
    final keys =
        publicNetworkSchemas['PublicWorkspaceDocument']!.fields.keys.toList()
          ..sort();
    expect(
      File(_pgtap).readAsStringSync(),
      contains("array[${keys.map((k) => "'$k'").join(',')}]"),
      reason: '$_pgtap must assert the projection keys the contract lists',
    );
  });

  test('public operations are anonymous reads; nothing else is', () {
    for (final op in publicNetworkOperations.values) {
      expect(
        op.surface == PublicSurface.public,
        op.principal == PublicPrincipal.anonymous,
        reason: op.id,
      );
      if (op.surface == PublicSurface.public) {
        expect(op.mutation, PublicMutation.read, reason: op.id);
        expect(op.relation, isNotNull, reason: op.id);
      }
    }
  });
}
