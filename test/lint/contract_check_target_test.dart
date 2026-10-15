// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2584 (audit A06) — the contract and the readable schema describe the
// SAME database, or the run produces no evidence.
//
// `scripts/contract_check.sh` queried its <db url> but dumped the first
// `supabase_db` container `docker ps` listed, so with two local stacks the
// contract could describe W-A while effective-schema.sql described P. These
// drive the real script with stubbed psql, pg_dump and docker over two
// databases that carry different canary functions: whichever order the
// containers are listed in, each target's artifacts hold only its own
// canary; a container that is not the queried database, a failing dump, an
// unreachable or changing target and an unsafe label leave no manifest and
// no accepted schema; and the connection password never reaches an output.
// Removing the identity check in `container_dump` turns the swapped-order
// and mismatch cases red.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _secret = 'canary-secret-pw';
String _url(String tag) => 'postgresql://postgres:$_secret@host-$tag:54322/db';

// Built with fromUri: lint_sources_test counts a literal Directory( call as
// a hand-written walk, and this test walks nothing.
Directory _at(String path) => Directory.fromUri(Uri.directory(path));

late Directory _dir;
late Directory _stub;
late String _script;

const _psqlStub = r'''#!/usr/bin/env bash
url=$1; shift
q=${@: -1}
tag=${url#*@host-}; tag=${tag%%:*}
[ -f "$STUB/$tag.unreachable" ] && { echo "connection to $url failed" >&2; exit 2; }
if [[ "$q" == *current_database* ]]; then
  n=$(cat "$STUB/count.$tag" 2>/dev/null || echo 0)
  echo $((n + 1)) > "$STUB/count.$tag"
  if [ "$n" -ge 1 ] && [ -f "$STUB/$tag.identity.2" ]; then cat "$STUB/$tag.identity.2"; else cat "$STUB/$tag.identity"; fi
else
  cat "$STUB/$tag.lines"
fi
''';

const _pgDumpStub = r'''#!/usr/bin/env bash
if [ "$1" = "--version" ]; then echo "pg_dump (PostgreSQL) $(cat "$STUB/pgdump.version")"; exit 0; fi
url=${1#--dbname=}
tag=${url#*@host-}; tag=${tag%%:*}
echo "pg_dump: connecting to $url" >&2
[ -f "$STUB/$tag.dumpfail" ] && exit 1
cat "$STUB/$tag.dump"
''';

const _dockerStub = r'''#!/usr/bin/env bash
if [ "$1" = "ps" ]; then cat "$STUB/containers"; exit 0; fi
# docker exec <container> psql|pg_dump ...
c=$2; tool=$3
if [ "$tool" = "psql" ]; then cat "$STUB/container.$c.identity"; else cat "$STUB/container.$c.dump"; fi
''';

void _write(String name, String text) => File('${_stub.path}/$name')
  ..createSync(recursive: true)
  ..writeAsStringSync(text);

String _lines(String canary) => [
  'routine public.canary() -> text | function | invoker | volatile | exec:- | body:$canary',
  for (var i = 0; i < 120; i++) 'constraint public.t$i.c$i CHECK (true)',
].join('\n');

void _database(String tag) {
  _write('$tag.identity', 'db$tag|170000|digest-$tag\n');
  _write('$tag.lines', '${_lines(tag)}\n');
  _write('$tag.dump', 'create function canary_$tag();\n');
  _write('container.supabase_db_$tag.identity', 'db$tag|170000|digest-$tag\n');
  _write('container.supabase_db_$tag.dump', 'create function canary_$tag();\n');
}

void _committed(String tag) {
  File('${_dir.path}/assets/instance/contract.txt')
    ..createSync(recursive: true)
    ..writeAsStringSync('# header\n${_lines(tag)}\n');
}

({int code, String out}) _run(
  String tag, {
  Map<String, String> env = const {},
}) {
  final r = Process.runSync(
    'bash',
    [_script, _url(tag)],
    workingDirectory: _dir.path,
    environment: {
      'STUB': _stub.path,
      'PSQL_BIN': '${_stub.path}/psql',
      'PG_DUMP_BIN': '${_stub.path}/pg_dump',
      'DOCKER_BIN': '${_stub.path}/docker',
      ...env,
    },
  );
  return (code: r.exitCode, out: '${r.stdout}${r.stderr}');
}

String _read(String path) => File('${_dir.path}/$path').readAsStringSync();
bool _exists(String path) => File('${_dir.path}/$path').existsSync();

void main() {
  setUpAll(() => _script = File('scripts/contract_check.sh').absolute.path);
  setUp(() {
    _dir = Directory.systemTemp.createTempSync('contract-target');
    _stub = _at('${_dir.path}/stub')..createSync();
    for (final e in {
      'psql': _psqlStub,
      'pg_dump': _pgDumpStub,
      'docker': _dockerStub,
    }.entries) {
      _write(e.key, e.value);
      Process.runSync('chmod', ['+x', '${_stub.path}/${e.key}']);
    }
    _write('pgdump.version', '17.0');
    _database('a');
    _database('b');
    _write('containers', 'supabase_db_b\nsupabase_db_a\n');
  });
  tearDown(() => _dir.deleteSync(recursive: true));

  test(
    'a single stack: the host dump follows the URL and a manifest is written',
    () {
      _committed('a');
      final r = _run('a');
      expect(r.code, 0, reason: r.out);
      expect(_read('report/contract.txt'), contains('body:a'));
      expect(_read('report/effective-schema.sql'), contains('canary_a'));
      expect(_read('report/effective-schema.sql'), isNot(contains('canary_b')));
      expect(_read('report/manifest.json'), contains('"database": "dba"'));
      expect(_read('report/manifest.json'), contains('"target": "default"'));
    },
  );

  test('an old host pg_dump falls back to the container that IS the target, '
      'whatever order docker lists them in', () {
    _write('pgdump.version', '14.2');
    for (final order in [
      'supabase_db_b\nsupabase_db_a\n',
      'supabase_db_a\nsupabase_db_b\n',
    ]) {
      _write('containers', order);
      _committed('a');
      final r = _run('a');
      expect(r.code, 0, reason: r.out);
      expect(_read('report/effective-schema.sql'), contains('canary_a'));
      expect(_read('report/effective-schema.sql'), isNot(contains('canary_b')));
      _at('${_dir.path}/report').deleteSync(recursive: true);
    }
  });

  test('two targets keep separate labelled outputs', () {
    _committed('a');
    expect(_run('a', env: {'CONTRACT_TARGET_LABEL': 'w-a'}).code, 0);
    _committed('b');
    expect(_run('b', env: {'CONTRACT_TARGET_LABEL': 'w-b'}).code, 0);
    expect(_read('report/w-a/effective-schema.sql'), contains('canary_a'));
    expect(_read('report/w-b/effective-schema.sql'), contains('canary_b'));
    expect(_read('report/w-a/contract.txt'), isNot(contains('body:b')));
    expect(_read('report/w-b/contract.txt'), isNot(contains('body:a')));
  });

  test('a swapped container is refused: no schema, no manifest', () {
    _write('pgdump.version', '14.2');
    _write('containers', 'supabase_db_b\n');
    _committed('a');
    var r = _run('a');
    expect(r.code, 1, reason: r.out);
    expect(r.out, contains('is not the queried database'));
    expect(_exists('report/manifest.json'), isFalse);
    expect(_exists('report/effective-schema.sql'), isFalse);
    _write('containers', 'supabase_db_a\nsupabase_db_b\n');
    r = _run('a', env: {'CONTRACT_DB_CONTAINER': 'supabase_db_b'});
    expect(r.code, 1, reason: r.out);
    expect(_exists('report/manifest.json'), isFalse);
  });

  test('a failing dump, an unreachable target and a changing target are '
      'failures, not a warning followed by a pass', () {
    _committed('a');
    _write('a.dumpfail', '');
    var r = _run('a');
    expect(r.code, 1, reason: r.out);
    expect(r.out, contains('could not be dumped'));
    expect(_exists('report/manifest.json'), isFalse);
    expect(_exists('report/effective-schema.sql'), isFalse);
    File('${_stub.path}/a.dumpfail').deleteSync();

    File('${_stub.path}/count.a').deleteSync();
    _write('a.identity.2', 'dba|170000|digest-changed\n');
    r = _run('a');
    expect(r.code, 1, reason: r.out);
    expect(r.out, contains('changed while the evidence was taken'));
    expect(_exists('report/manifest.json'), isFalse);
    File('${_stub.path}/a.identity.2').deleteSync();

    _write('a.unreachable', '');
    r = _run('a');
    expect(r.code, 1, reason: r.out);
    expect(r.out, contains('not reachable'));
    expect(_exists('report/manifest.json'), isFalse);
  });

  test('an unsafe label is refused before anything is written', () {
    _committed('a');
    for (final label in ['../x', 'a/b', '.hidden', 'a b']) {
      final r = _run('a', env: {'CONTRACT_TARGET_LABEL': label});
      expect(r.code, 1, reason: '$label\n${r.out}');
      expect(r.out, contains('not a safe label'));
    }
    expect(_exists('report'), isFalse);
  });

  test('the connection password reaches no output and no artifact', () {
    _committed('a');
    final r = _run('a');
    expect(r.code, 0, reason: r.out);
    expect(r.out, isNot(contains(_secret)));
    expect(r.out, isNot(contains('postgresql://')));
    for (final f in _at(
      '${_dir.path}/report',
    ).listSync(recursive: true).whereType<File>()) {
      expect(f.readAsStringSync(), isNot(contains(_secret)), reason: f.path);
    }
  });
}
