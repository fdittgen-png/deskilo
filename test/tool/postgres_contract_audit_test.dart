// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2594 -- the generic contract collector takes its schemas, roles and output
// from its inputs and refuses what is not plain. A stub `psql` records the SQL
// it is sent; the real catalogue run is `tools/postgres_contract_audit/test/run.sh`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _psqlStub = r'''#!/usr/bin/env bash
url=$1; shift
q=${@: -1}
printf '%s\n---\n' "$q" >> "$STUB/queries"
if [[ "$q" == *current_database* ]]; then
  echo 'neutral|170000|digest'
else
  echo 'routine library.f() -> text | function | invoker | stable | exec:- | body:abc'
fi
''';

const _pgDumpStub = r'''#!/usr/bin/env bash
if [ "$1" = "--version" ]; then echo "pg_dump (PostgreSQL) 17.0"; exit 0; fi
echo "args: $*" > "$STUB/dump.args"
echo 'create function library_f();'
''';

late Directory _dir;
late String _script;

Directory _at(String path) => Directory.fromUri(Uri.directory(path));

({int code, String out}) _run(Map<String, String> env) {
  final r = Process.runSync(
    'bash',
    [_script, 'postgresql://u:secret-pw@h:5432/neutral'],
    workingDirectory: _dir.path,
    environment: {
      'STUB': '${_dir.path}/stub',
      'PSQL_BIN': '${_dir.path}/stub/psql',
      'PG_DUMP_BIN': '${_dir.path}/stub/pg_dump',
      ...env,
    },
  );
  return (code: r.exitCode, out: '${r.stdout}${r.stderr}');
}

void main() {
  setUpAll(
    () =>
        _script = File('tools/postgres_contract_audit/pg_contract_audit.sh')
            .absolute
            .path,
  );
  setUp(() {
    _dir = Directory.systemTemp.createTempSync('pg-audit');
    _at('${_dir.path}/stub').createSync();
    for (final e in {'psql': _psqlStub, 'pg_dump': _pgDumpStub}.entries) {
      File('${_dir.path}/stub/${e.key}').writeAsStringSync(e.value);
      Process.runSync('chmod', ['+x', '${_dir.path}/stub/${e.key}']);
    }
  });
  tearDown(() => _dir.deleteSync(recursive: true));

  test(
    'the schemas, roles and policies named reach the SQL and the manifest',
    () {
      final r = _run({
        'AUDIT_SCHEMAS': 'library,archive',
        'AUDIT_ROLES': 'reader,clerk',
        'AUDIT_POLICIES': '1',
        'AUDIT_OUT_DIR': 'out',
      });
      expect(r.code, 0, reason: r.out);
      final sql = File('${_dir.path}/stub/queries').readAsStringSync();
      expect(sql, contains("array['library','archive']"));
      expect(sql, contains("has_function_privilege('reader'"));
      expect(sql, contains("has_function_privilege('clerk'"));
      expect(sql, contains('pg_policies'));
      expect(sql, isNot(contains("'public'")));
      final manifest = File('${_dir.path}/out/manifest.json')
          .readAsStringSync();
      expect(manifest, contains('"schemas": ["library","archive"]'));
      expect(manifest, contains('"roles": ["reader","clerk"]'));
      expect(
        File('${_dir.path}/stub/dump.args').readAsStringSync(),
        allOf(contains('--schema=library'), contains('--schema=archive')),
      );
    },
  );

  test('without roles or policies the SQL names none', () {
    final r = _run({'AUDIT_SCHEMAS': 'library'});
    expect(r.code, 0, reason: r.out);
    final sql = File('${_dir.path}/stub/queries').readAsStringSync();
    expect(sql, isNot(contains('has_function_privilege')));
    expect(sql, isNot(contains('pg_policies')));
    expect(
      File('${_dir.path}/audit-out/contract.txt').readAsStringSync(),
      startsWith('# The effective contract'),
    );
  });

  test('what is not plain is refused before anything is read or written', () {
    for (final env in [
      {'AUDIT_SCHEMAS': "library'; drop table x; --"},
      {'AUDIT_ROLES': 'a b'},
      {'AUDIT_OUT_DIR': '../escape'},
      {'AUDIT_OUT_DIR': '/abs'},
      {'AUDIT_TARGET_LABEL': '../x'},
      {'AUDIT_MIN_LINES': 'many'},
      {'AUDIT_POLICIES': 'yes'},
    ]) {
      final r = _run(env);
      expect(r.code, 1, reason: '$env\n${r.out}');
    }
    expect(File('${_dir.path}/stub/queries').existsSync(), isFalse);
    expect(_at('${_dir.path}/audit-out').existsSync(), isFalse);
  });

  test('the password reaches no output', () {
    final r = _run({});
    expect(r.out, isNot(contains('secret-pw')));
    final manifest = File('${_dir.path}/audit-out/manifest.json')
        .readAsStringSync();
    expect(manifest, isNot(contains('secret-pw')));
  });
}
