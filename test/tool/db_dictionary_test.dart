// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1911 — the data dictionary is generated from the catalogues, complete,
// deterministic and safe to open: counts equal the catalogue, a dropped
// field or relationship is detected, nothing from catalogue strings can
// run as script, and every committed rendering is what the committed
// extraction renders.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/build_db_dictionary.dart' as cli;
import '../../tool/db_dictionary/render.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> _fixture() =>
    _json('test/fixtures/db_dictionary/fixture.json');

Map<String, dynamic> _object(Map<String, dynamic> d, String name) =>
    (d['objects'] as List).cast<Map<String, dynamic>>().firstWhere(
      (o) => o['name'] == name,
    );

void main() {
  group('the fixture schema', () {
    test('is complete: the declared counts equal what the objects hold', () {
      expect(verifyDictionary(_fixture()), isEmpty);
    });

    test('a deliberately omitted column is detected', () {
      final d = _fixture();
      (_object(d, 'workspaces')['columns'] as List).removeLast();
      expect(verifyDictionary(d), contains(startsWith('count columns:')));
    });

    test('a deliberately omitted relationship is detected', () {
      final d = _fixture();
      (_object(d, 'bookings')['constraints'] as List).removeWhere(
        (c) => (c as Map)['type'] == 'foreign key',
      );
      expect(verifyDictionary(d), contains(startsWith('count foreignKeys:')));
    });

    test('a relationship to a table that is not there is detected', () {
      final d = _fixture();
      final fk = (_object(d, 'bookings')['constraints'] as List).firstWhere(
        (c) => (c as Map)['type'] == 'foreign key',
      ) as Map;
      (fk['references'] as Map)['table'] = 'ghosts';
      expect(verifyDictionary(d), contains(contains('unknown target')));
    });

    test('a managed table is a reference, not a missing object', () {
      expect(
        verifyDictionary(_fixture()),
        isNot(contains(contains('auth.users'))),
      );
    });
  });

  group('relationships', () {
    final rels = relationshipsOf(_fixture());

    test('a composite key keeps its column order, SET NULL its columns', () {
      final r = rels.firstWhere((r) => r.name == 'bookings_member_fkey');
      expect(r.fromColumns, ['workspace_id', 'member_id']);
      expect(r.toColumns, ['workspace_id', 'user_id']);
      expect(r.onDelete, 'SET NULL (member_id)');
      expect(r.validated, isFalse);
      expect(r.kind, 'defined');
    });

    test('a foreign key across schemas is qualified', () {
      final r = rels.firstWhere((r) => r.name == 'invoices_ws_fkey');
      expect(r.from, 'billing.invoices');
      expect(r.to, 'public.workspaces');
    });

    test('a naming match without a constraint is inferred and says so', () {
      final inferred = rels.where((r) => r.kind == 'inferred').toList();
      expect(inferred.map((r) => '${r.from}.${r.fromColumns.single}'), [
        'public.import_staging.workspace_id',
      ]);
      expect(rels.where((r) => r.kind == 'defined'), hasLength(4));
    });

    test('company_id and site_id are never inferred as keys', () {
      final d = _fixture();
      (d['objects'] as List).add({
        'schema': 'public',
        'name': 'sites',
        'kind': 'table',
        'columns': [
          {'position': 1, 'name': 'id', 'type': 'uuid', 'notNull': true},
        ],
        'constraints': [
          {
            'name': 'sites_pkey',
            'type': 'primary key',
            'columns': ['id'],
            'definition': 'PRIMARY KEY (id)',
          },
        ],
        'indexes': <Object>[],
      });
      final inferred = relationshipsOf(d).where((r) => r.kind == 'inferred');
      expect(
        inferred.where((r) => r.toTable == 'sites'),
        isEmpty,
        reason: 'site_id is a tenancy stamp on every table',
      );
    });

    test('the CSV lists defined keys first and marks inferred ones', () {
      final lines = relationshipsCsv(_fixture()).trim().split('\n');
      expect(lines.first, startsWith('kind,from,'));
      expect(lines.where((l) => l.startsWith('defined,')), hasLength(4));
      expect(lines.where((l) => l.startsWith('inferred,')), hasLength(1));
      expect(
        lines.indexWhere((l) => l.startsWith('inferred,')),
        greaterThan(4),
      );
    });
  });

  group('the renderings', () {
    test('columns.csv has one row per column, types and keys intact', () {
      final d = _fixture();
      final lines = columnsCsv(d).trim().split('\n');
      expect(
        lines.length - 1,
        (d['meta'] as Map)['counts']['columns'],
        reason: 'one row per catalogue column',
      );
      expect(
        lines,
        contains(
          startsWith('public,workspaces,table,3,price,"numeric(12,2)",true,0,'),
        ),
      );
      expect(
        lines,
        contains(startsWith('public,workspaces,table,4,tags,text[],false,')),
      );
      expect(
        lines,
        contains(startsWith('public,workspaces,table,8,seq,integer,true,,a,')),
      );
      expect(
        lines,
        contains(
          startsWith(
            'public,workspaces,table,7,name_lower,text,false,lower(name),,s,',
          ),
        ),
      );
      expect(
        lines,
        contains(
          startsWith(
            'public,members,table,2,user_id,uuid,true,,,,true,auth.users.id',
          ),
        ),
      );
    });

    test('the output does not depend on the order of the input', () {
      final a = renderDictionary(_fixture());
      final d = _fixture();
      d['objects'] = (d['objects'] as List).reversed.toList();
      expect(renderDictionary(d), a);
      expect(renderDictionary(_fixture()), a, reason: 'twice, byte for byte');
    });

    test('the page covers every object kind with links to the sections', () {
      final html = dictionaryHtml(_fixture());
      for (final id in [
        't-public__workspaces',
        't-public__events_2026',
        't-public__open_workspaces',
        't-billing__invoices',
        'c-public__workspaces__price',
      ]) {
        expect(html, contains('id="$id"'));
      }
      expect(html, contains('href="#t-public__workspaces"'));
      expect(html, contains('FOR VALUES FROM'));
      expect(html, contains('No constraints (no primary key).'));
      expect(html, contains('<svg'));
      expect(html, contains('status_kind'));
    });

    test('it opens offline: nothing is fetched, one static script', () {
      final html = dictionaryHtml(_fixture());
      expect(html, isNot(contains('http://')));
      expect(html, isNot(contains('https://')));
      expect(html, isNot(contains('<link')));
      expect(html, isNot(contains(' src=')));
      expect(RegExp('<script').allMatches(html), hasLength(1));
      expect(html, contains("default-src 'none'"));
    });

    test('catalogue strings cannot become markup or script', () {
      final d = _fixture();
      const evil = '<script>alert(1)</script>"><img src=x onerror=alert(2)>';
      final o = _object(d, 'workspaces');
      o['comment'] = evil;
      (o['columns'] as List).first['name'] = evil;
      (o['columns'] as List).first['default'] = evil;
      d['objects'] = [
        ...(d['objects'] as List),
        {
          'schema': 'public',
          'name': evil,
          'kind': 'table',
          'columns': <Object>[],
          'constraints': <Object>[],
          'indexes': <Object>[],
        },
      ];
      final html = dictionaryHtml(d);
      expect(html, isNot(contains('<script>alert')));
      expect(html, isNot(contains('<img src=x')));
      expect(html, isNot(contains('onerror=alert(2)>')));
      expect(RegExp('<script').allMatches(html), hasLength(1));
      expect(
        RegExp(r'id="([^"]*)"')
            .allMatches(html)
            .every((m) => RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(m.group(1)!)),
        isTrue,
        reason: 'anchors are sanitised, whatever the identifier says',
      );
    });
  });

  group('the committed dictionary', () {
    final committed = _json('docs/database/dictionary.json');

    test('is complete and self-consistent', () {
      expect(verifyDictionary(committed), isEmpty);
      final counts = (committed['meta'] as Map)['counts'] as Map;
      expect(counts['tables'], greaterThan(100));
      expect(counts['foreignKeys'], greaterThan(200));
    });

    test('names the schema marker the migrations end at', () {
      final marker = RegExp(r'requiredSchemaVersion = (\d+)')
          .firstMatch(
            File('lib/core/instance/schema_compatibility.dart')
                .readAsStringSync(),
          )!
          .group(1);
      expect('${(committed['meta'] as Map)['schemaMarker']}', marker);
    });

    test('carries no secret default and no row data', () {
      final sensitive = RegExp(
        '(secret|token|passw|credential|api_?key|private_?key|vault|e_?mail|'
        'phone|iban|first_?name|last_?name)',
        caseSensitive: false,
      );
      for (final o
          in (committed['objects'] as List).cast<Map<String, dynamic>>()) {
        for (final c in (o['columns'] as List).cast<Map<String, dynamic>>()) {
          if (sensitive.hasMatch('${c['name']}')) {
            expect(
              c['default'] == null || c['default'] == '<redacted>',
              isTrue,
              reason: '${o['name']}.${c['name']} exposes a default',
            );
          }
        }
        expect(o.containsKey('rows'), isFalse);
        expect(o.containsKey('definition'), isFalse, reason: 'no view source');
      }
      final text = File('docs/database/dictionary.json').readAsStringSync();
      expect(text, isNot(contains('eyJ')), reason: 'a JWT');
      expect(text, isNot(contains('PRIVATE KEY')));
      expect(text, isNot(contains('sk_live')));
    });

    test('every committed rendering is what it renders', () {
      for (final e in renderDictionary(committed).entries) {
        expect(
          File(e.key).readAsStringSync() == e.value,
          isTrue,
          reason:
              '${e.key} is stale — run dart run tool/build_db_dictionary.dart',
        );
      }
    });

    test('the CLI agrees: --check exits 0', () {
      expect(cli.run(['--check']), 0);
    });
  });

  group('the extraction query', () {
    final sql = File('scripts/db_dictionary.sql').readAsStringSync();

    test('reads catalogues only: no rows, no function or view source', () {
      for (final forbidden in [
        'pg_get_functiondef',
        'pg_get_viewdef',
        'pg_proc',
        'prosrc',
        'insert ',
        'update ',
        'delete ',
      ]) {
        expect(
          sql.toLowerCase(),
          isNot(contains(forbidden)),
          reason: forbidden,
        );
      }
      expect(sql, contains('<redacted>'));
      expect(sql, contains("n.nspname = 'public'"));
    });

    test('the operator export is read-only and checks for intervening DDL', () {
      final sh = File('scripts/db_dictionary.sh').readAsStringSync();
      expect(sh, contains('read only'));
      expect(sh, contains('DDL in between'));
    });
  });
}
