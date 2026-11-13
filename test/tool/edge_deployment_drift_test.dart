// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3520 -- tool/edge_deployment_drift.dart: the same set is clean, a missing
// function, an orphan and a flipped verify_jwt are named, and everything the
// check could not look at is "not verified" -- never a pass.
import 'dart:io';

import 'package:deskilo/core/instance/management_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/edge_deployment_drift.dart';
import '../helpers/fake_supabase_management.dart';
import '../helpers/tool_process.dart';

const _local = {'a': true, 'b': false, 'c': true};
const _ref = 'devref';

class _Throwing extends FakeSupabaseManagement {
  _Throwing(this.error);
  final Exception error;
  @override
  Future<List<({String slug, bool? verifyJwt})>> listDeployedFunctions(
    String ref,
  ) async => throw error;
}

void main() {
  group('compare', () {
    test('identical sets are verified', () {
      final r = compare([
        (slug: 'a', verifyJwt: true),
        (slug: 'b', verifyJwt: false),
        (slug: 'c', verifyJwt: true),
      ], _local);
      expect(r.status, DriftStatus.verified);
      expect(r.problems, isEmpty);
      expect(r.rows, hasLength(3));
    });

    test('a missing function is named, an orphan only counted', () {
      final r = compare([
        (slug: 'a', verifyJwt: true),
        (slug: 'b', verifyJwt: false),
        (slug: 'zombie', verifyJwt: true),
      ], _local);
      expect(r.status, DriftStatus.drift);
      expect(r.problems, contains(contains('c is in supabase/functions but not deployed')));
      expect(r.problems,
          contains('1 deployed function is not in the repository \u2014 list them with the management console'));
      expect('${r.problems}${r.rows}', isNot(contains('zombie')));
    });

    test('a verify_jwt flip names both values', () {
      final r = compare([
        (slug: 'a', verifyJwt: false),
        (slug: 'b', verifyJwt: false),
        (slug: 'c', verifyJwt: true),
      ], _local);
      expect(r.status, DriftStatus.drift);
      expect(r.problems.single,
          'a: verify_jwt is true in the repository and false on dev');
    });

    test('a remote entry that does not say verify_jwt is not verified', () {
      final r = compare([
        (slug: 'a', verifyJwt: true),
        (slug: 'b', verifyJwt: null),
        (slug: 'c', verifyJwt: true),
      ], _local);
      expect(r.status, DriftStatus.notVerified);
      expect(r.problems.single, contains('did not say its verify_jwt'));
    });

    test('an unreadable list is not verified', () {
      expect(compare(null, _local).status, DriftStatus.notVerified);
    });
  });

  group('run', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('edge_drift'));
    tearDown(() => tmp.deleteSync(recursive: true));

    FakeSupabaseManagement fake() => FakeSupabaseManagement()
      ..deployed[_ref] = [
        (slug: 'a', verifyJwt: true),
        (slug: 'b', verifyJwt: false),
        (slug: 'c', verifyJwt: true),
      ];

    Future<(int, String, String)> go(
      Map<String, String> env,
      SupabaseManagement api, {
      List<String> args = const ['--ref', _ref, '--expected-ref', _ref],
    }) async {
      final out = StringBuffer();
      final summary = '${tmp.path}/summary.md';
      final code = await run(
        [...args, '--summary', summary],
        env,
        (_) => api,
        local: _local,
        out: out,
      );
      final s = File(summary);
      return (code, '$out', s.existsSync() ? s.readAsStringSync() : '');
    }

    test('a matching project exits 0 and says verified', () async {
      final (code, out, summary) = await go({'SUPABASE_ACCESS_TOKEN': 't'}, fake());
      expect(code, 0, reason: out);
      expect(summary, contains('verified: 3 functions match'));
    });

    test('an orphan\'s slug appears nowhere in the output, exit stays 1',
        () async {
      final api = fake()..deployed[_ref]!.add((slug: 'zombie', verifyJwt: true));
      final (code, out, summary) = await go({'SUPABASE_ACCESS_TOKEN': 't'}, api);
      expect(code, 1, reason: out);
      expect(out + summary, isNot(contains('zombie')));
      expect(summary, contains('1 deployed function is not in the repository'));
    });

    test('drift exits 1 and the summary names it', () async {
      final api = fake()..deployed[_ref]!.removeLast();
      final (code, out, summary) = await go({'SUPABASE_ACCESS_TOKEN': 't'}, api);
      expect(code, 1, reason: out);
      expect(summary, contains('DRIFT'));
      expect(summary, contains('| c | true | - | MISSING on dev |'));
    });

    test('no token is NOT VERIFIED, exit 3, never a pass', () async {
      final (code, out, summary) = await go({}, fake());
      expect(code, 3);
      expect(out, contains('NOT VERIFIED'));
      expect(summary, contains('SUPABASE_ACCESS_TOKEN is not set'));
    });

    test('no ref, or no expected ref, is NOT VERIFIED', () async {
      final noRef = await go({'SUPABASE_ACCESS_TOKEN': 't'}, fake(),
          args: ['--ref', '', '--expected-ref', _ref]);
      expect(noRef.$1, 3);
      final noExpected = await go({'SUPABASE_ACCESS_TOKEN': 't'}, fake(),
          args: ['--ref', _ref]);
      expect(noExpected.$1, 3);
      expect(noExpected.$3, contains('identity check'));
    });

    test('a pasted ref that is not the dev project is never read', () async {
      final api = _Throwing(Exception('must not be called'));
      final (code, out, _) = await go({'SUPABASE_ACCESS_TOKEN': 't'}, api,
          args: ['--ref', 'prodref', '--expected-ref', _ref]);
      expect(code, 3, reason: out);
      expect(out, contains('nothing was read'));
    });

    test('a refused token, a server error and garbage are NOT VERIFIED',
        () async {
      for (final error in <Exception>[
        const ManagementApiException(401, 'secret body text'),
        const ManagementApiException(500, 'secret body text'),
        const FormatException('malformed json'),
      ]) {
        final (code, out, summary) =
            await go({'SUPABASE_ACCESS_TOKEN': 'tok'}, _Throwing(error));
        expect(code, 3, reason: '$error');
        expect(out + summary, isNot(contains('secret body text')),
            reason: 'a response body never reaches a public log');
        expect(out + summary, isNot(contains('tok\n')));
      }
    });
  });

  test('the workflow is manual, read-only, and gives the token to one step',
      () {
    final text = File('.github/workflows/edge-drift.yml').readAsStringSync();
    final doc = loadYaml(text) as YamlMap;
    final on = doc['on'] as YamlMap;
    expect(on.keys.toSet(), {'workflow_dispatch'},
        reason: 'no schedule until the credentials exist (#3750)');
    expect(doc['permissions'], {'contents': 'read'});
    final steps =
        (((doc['jobs'] as YamlMap)['drift'] as YamlMap)['steps'] as YamlList)
            .cast<YamlMap>();
    final withToken = steps.where((s) => '$s'.contains('secrets.SUPABASE_ACCESS_TOKEN'));
    expect(withToken, hasLength(1));
    final run = '${withToken.single['run']}';
    expect(run, contains('edge_drift'));
    final all = steps.map((st) => '$st').toList();
    final compile = steps.singleWhere((st) => '${st['run']}'.contains('dart compile exe'));
    expect('$compile', isNot(contains('SUPABASE_ACCESS_TOKEN')),
        reason: 'compiling runs package code: no token in that step');
    expect(steps.indexOf(compile), lessThan(steps.indexOf(withToken.single)));
    expect(all.where((t) => t.contains('dart run')), isEmpty);
    expect(run, contains(r'"$EXPECTED_REF"'));
    expect(text, isNot(contains('pull_request')));
    expect(text, isNot(contains('if: ')),
        reason: 'no step may be skipped: a skipped check reads as passed');
  });

  test('the process exits nonzero without a token (Dart ignores main)', () {
    final r = runToolSync(
      'tool/edge_deployment_drift.dart',
      ['--ref', _ref, '--expected-ref', _ref],
      environment: {'PATH': Platform.environment['PATH'] ?? '', 'HOME': Platform.environment['HOME'] ?? ''},
    );
    expect(r.exitCode, 3, reason: '${r.stdout}${r.stderr}');
    expect('${r.stdout}', contains('NOT VERIFIED'));
  });
}
