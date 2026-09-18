// SPDX-License-Identifier: 0BSD
//
// #1337 — the psql adapter under the lifecycle check answers the way the
// Management API does: a migration is ONE query, rows come back typed, and
// a database error is a ManagementApiException the doctor's probe
// isolation catches. If the adapter lied, the CI proof would prove nothing.
import 'dart:io';

import 'package:deskilo/core/instance/instance_builder.dart';
import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:deskilo/core/instance/management_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/instance_lifecycle/psql_management.dart';

typedef _Call = ({String executable, List<String> args});

PsqlSupabaseManagement _api(
  List<_Call> calls,
  ProcessResult Function(List<String> args) answer,
) => PsqlSupabaseManagement(
  psql: const ['docker', 'exec', 'db', 'psql', '-U', 'postgres'],
  functionSlugs: const ['send-push'],
  runner: (executable, args) async {
    calls.add((executable: executable, args: args));
    return answer(args);
  },
);

ProcessResult _ok(String stdout) => ProcessResult(1, 0, stdout, '');

void main() {
  test('a query is wrapped once, trailing semicolons and all', () {
    expect(
      jsonRowsSql('select 1 as a;\n;  \n'),
      "select coalesce(json_agg(q), '[]'::json) from (\nselect 1 as a\n) q",
    );
  });

  test('rows keep their JSON types, and nothing printed is no row', () {
    final rows = parseJsonRows(
      '[{"marker":240,"present":true,"versions":"0001,0002","x":null}, \n'
      ' {"marker":null,"present":false,"versions":"","x":1.5}]\n',
    );
    expect(rows, [
      {'marker': 240, 'present': true, 'versions': '0001,0002', 'x': null},
      {'marker': null, 'present': false, 'versions': '', 'x': 1.5},
    ]);
    expect(parseJsonRows('  \n'), isEmpty);
    expect(() => parseJsonRows('{"a":1}'), throwsFormatException);
  });

  test('an error keeps the database words, not the psql prefix', () {
    expect(
      psqlErrorMessage(
        'NOTICE:  extension exists, skipping\n'
        'ERROR:  division by zero\n'
        'CONTEXT:  SQL statement\n'
        'HINT:  do not divide by zero\n',
      ),
      'division by zero\nHINT:  do not divide by zero',
    );
    expect(
      psqlErrorMessage('psql: error: connection refused\n'),
      'psql: error: connection refused',
    );
    expect(psqlErrorMessage(''), 'psql failed without a message');
  });

  test('the version a recorded migration writes is read back', () {
    final sql = InstanceBuilder.recordedMigrationSql((
      name: '0230_template_change_set.sql',
      sql: 'select 1;',
    ));
    expect(recordedVersionOf(sql), '0230');
    expect(recordedVersionOf('select 1'), isNull);
  });

  test(
    'a migration and its record are ONE psql query on the ref database',
    () async {
      final calls = <_Call>[];
      final api = _api(calls, (_) => _ok(''));
      final sql = InstanceBuilder.recordedMigrationSql((
        name: '0001_a.sql',
        sql: 'create table public.a (id int);',
      ));
      await api.runSql('lifecycle_install', sql);

      expect(calls, hasLength(1));
      expect(calls.single.executable, 'docker');
      final args = calls.single.args;
      expect(args.take(5), ['exec', 'db', 'psql', '-U', 'postgres']);
      expect(args[args.indexOf('-d') + 1], 'lifecycle_install');
      expect(args.last, sql, reason: 'the whole string, one -c');
      expect(args.where((a) => a == '-c'), hasLength(1));
      expect(args, isNot(contains('-f')));
      expect(api.mutations, [sql]);
    },
  );

  test(
    'a failing statement is a 400 the doctor isolates to its probe',
    () async {
      final calls = <_Call>[];
      final api = _api(calls, (args) {
        final sql = args.last;
        if (sql.contains('1 / 0')) {
          return ProcessResult(1, 1, '', 'ERROR:  division by zero\n');
        }
        if (sql.contains('auth.users')) {
          return ProcessResult(
            1,
            1,
            '',
            'ERROR:  relation "auth.users" does not exist\n',
          );
        }
        return _ok(
          '[{"tables_without_rls":"","open_policyless":"",'
          '"anon_definers":"","buckets":"avatars, floor-plans"}]',
        );
      });

      await expectLater(
        api.runSql('db', 'select 1 / 0'),
        throwsA(isA<ManagementApiException>()),
      );
      final findings = await InstanceDoctor(api).examine('db');
      final signUps = findings.where((f) => f.title == 'Sign-ups query failed');
      expect(signUps, hasLength(1));
      expect(signUps.single.detail, contains('400'));
      expect(findings.map((f) => f.title), contains('Row-level security'));
    },
  );

  test('a psql that cannot connect is not mistaken for a SQL answer', () async {
    final api = _api([], (_) => ProcessResult(1, 2, '', 'connection refused'));
    await expectLater(
      api.query('db', 'select 1'),
      throwsA(
        isA<ManagementApiException>().having((e) => e.status, 'status', 500),
      ),
    );
  });

  test('what only a hosted project has is answered, not exercised', () async {
    final api = _api([], (_) => _ok(''));
    expect((await api.project('db')).status, 'ACTIVE_HEALTHY');
    expect(await api.listFunctions('db'), ['send-push']);
    expect(
      InstanceDoctor.checkAuthConfig(await api.authConfig('db')),
      everyElement(predicate<DoctorFinding>((f) => !f.isProblem)),
    );
    await api.deployFunction(
      'db',
      slug: 'send-push',
      verifyJwt: true,
      files: const [],
    );
    expect(api.notCovered, ['deploy send-push']);
    expect(api.mutations, isEmpty);
  });
}
