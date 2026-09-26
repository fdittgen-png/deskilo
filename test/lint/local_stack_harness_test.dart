// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 C5 — one local stack per job, and nothing order-dependent on it.
//
// The database job starts its stack once, as the migration replay, and
// every consumer attaches to that stack: the address comes from the
// composite action's output, never from a second start. Fixtures that
// stay in the shared database run after every step that expects to find
// only its own rows there; drills that need a database of their own
// come last. Every pgTAP file is one transaction that rolls back, and
// every script the job runs either names its rows by run, removes them,
// works in its own database, or writes nothing. A producer added later
// (MCP, auth) is one more step after the stack, and this lint says so
// when it is not.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _action = './.github/actions/local-stack';
const _actionFile = '.github/actions/local-stack/action.yml';
const _address = r'${{ steps.migrations.outputs.db-url }}';

/// Steps whose fixtures stay in the shared database (the restore seed
/// persists; `restore` is the boundary) and the two that work in their
/// own databases, in the order the job must keep them.
const _sharedThenOwn = [
  'race', 'flags', 'payments', 'settlement', // own rows, removed or by run
  'restore', // the seed persists: after the four above
  'lifecycle', 'archive', // own databases; archive reads lifecycle's
];

YamlMap _yaml(String path) =>
    loadYaml(File(path).readAsStringSync()) as YamlMap;
/// A job that calls a reusable workflow has no steps of its own.
List<YamlMap> _steps(YamlMap job) =>
    ((job['steps'] as YamlList?) ?? YamlList()).cast<YamlMap>();
List<YamlMap> _database() =>
    _steps((_yaml('.github/workflows/quality.yml')['jobs'] as YamlMap)['database'] as YamlMap);
Iterable<File> _files(String dir, String ext) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith(ext));
String _run(YamlMap s) => '${s['run'] ?? ''}';

void main() {
  test('a local stack starts in exactly one place: the composite action', () {
    expect(File(_actionFile).readAsStringSync(), contains('supabase start'));
    for (final w in _files('.github/workflows', '.yml')) {
      for (final job in (_yaml(w.path)['jobs'] as YamlMap).values) {
        for (final s in _steps(job as YamlMap)) {
          expect(_run(s), isNot(contains('supabase start')), reason: w.path);
        }
      }
    }
    for (final s in _files('scripts', '.sh')) {
      final body = s.readAsStringSync();
      expect(body, isNot(contains('supabase start')), reason: s.path);
      expect(body, isNot(contains('supabase db reset')), reason: s.path);
    }
  });

  test('the database job starts it once, as the replay, and every consumer '
      'takes the address from that step', () {
    final steps = _database();
    final starts = steps.where((s) => s['uses'] == _action).toList();
    expect(starts, hasLength(1));
    expect(starts.single['id'], 'migrations');
    expect(starts.single['continue-on-error'], isTrue,
        reason: 'the replay is a row, and the gate reads its outcome');
    final after = steps.skip(steps.indexOf(starts.single) + 1);
    for (final s in after) {
      final run = _run(s);
      expect(run, isNot(contains('supabase status -o env | sed')),
          reason: '${s['name']}: the address is an output, not a re-derivation');
      if (run.contains(r'"$DB_URL"')) {
        expect((s['env'] as YamlMap?)?['DB_URL'], _address, reason: '${s['name']}');
      }
      // A discipline row runs only on a replayed stack; the diagnostics
      // step after a failure is the one legitimate other condition.
      if (s['continue-on-error'] == true) {
        expect(s['if'], "steps.migrations.outcome == 'success'",
            reason: '${s['name']}');
      }
    }
  });

  test('shared-database fixtures run before the seed that persists, and '
      'the own-database drills after it', () {
    final ids = _database().map((s) => '${s['id']}').toList();
    final positions = [for (final id in _sharedThenOwn) ids.indexOf(id)];
    expect(positions, isNot(contains(-1)), reason: '$ids');
    final restore = ids.indexOf('restore');
    for (final id in _sharedThenOwn.takeWhile((id) => id != 'restore')) {
      expect(ids.indexOf(id), lessThan(restore), reason: '$id after restore');
    }
    expect(restore, lessThan(ids.indexOf('lifecycle')));
    expect(ids.indexOf('lifecycle'), lessThan(ids.indexOf('archive')));
  });

  test('every pgTAP file is one transaction that rolls back', () {
    for (final f in _files('supabase/tests/database', '.sql')) {
      final statements = f
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('--'))
          .toList();
      expect(statements.first, 'begin;', reason: f.path);
      expect(statements.last, 'rollback;', reason: f.path);
    }
  });

  test('every script the job runs attaches to the running stack and leaves '
      'the shared database as it found it, or says which database is its own',
      () {
    final scripts = {
      for (final s in _database())
        ...RegExp(r'scripts/[a-z_]+\.sh').allMatches(_run(s)).map((m) => m[0]!),
    };
    expect(scripts, hasLength(greaterThanOrEqualTo(7)), reason: '$scripts');
    final dml = RegExp(r'^\s*(insert|update|delete|truncate)\s',
        caseSensitive: false, multiLine: true);
    for (final path in scripts) {
      final body = File(path).readAsStringSync();
      final isolated = body.contains(r'RUN="$$"') || // rows named by run
          body.contains('\ncleanup() {') || // rows removed
          body.contains('create database') || // a database of its own
          !dml.hasMatch(body); // writes nothing
      expect(isolated, isTrue,
          reason: '$path writes to the shared database and neither names '
              'its rows by run, removes them, nor works in its own database');
    }
  });
}
