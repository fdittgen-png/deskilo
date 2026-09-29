// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1633 — the operator's mcp-* commands. Inspection writes nothing. Enable
// needs the exact installation and epoch, re-measures, and without --apply
// only says what it would do; with it, it hands the database the evidence
// it measured, and the database's refusal is exit 1. A failed pilot
// switches MCP off. Reset refuses while MCP is on. No token, key or secret
// digest reaches the output, and the real process exits 2 on a wrong
// command line without echoing it.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/instance/mcp_readiness.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/instance/mcp_activation.dart';
import '../../tool/instance/mcp_collect.dart';
import '../helpers/fake_supabase_management.dart';
import '../helpers/mcp_cli_fakes.dart';
import '../helpers/mcp_target_fixture.dart';

class _Out implements IOSink {
  final text = StringBuffer();
  @override
  void writeln([Object? obj = '']) => text.writeln(obj);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<(int, String)> run(
  List<String> argv,
  FakeSupabaseManagement api, [
  FakeHttp? http,
]) async {
  final out = _Out();
  final code = await runMcp(
    argv,
    environment: env,
    api: api,
    http: http ?? FakeHttp(),
    release: (_) => fixtureRelease(),
    out: out,
  );
  final text = out.text.toString();
  expect(
    text,
    isNot(contains('PRIVATE')),
    reason: 'no token or key is ever printed',
  );
  expect(
    text,
    isNot(contains(digestOf(fixtureInstallation))),
    reason: 'no secret digest is printed',
  );
  return (code, text);
}

const target1 = ['--ref', fixtureRef];
const exact = ['--ref', fixtureRef, '--installation', fixtureInstallation];

void main() {
  group('mcp-inspect', () {
    test('a ready target exits 0 and says it is ready for a CONTROLLED activation only', () async {
      final api = target();
      final (code, text) = await run(['mcp-inspect', ...target1], api);
      expect(code, 0, reason: text);
      expect(text, contains('status: readyForControlledActivation'));
      expect(text, contains('not a business test'));
      expect(writes(api), isEmpty);
      expect(api.sql, isEmpty, reason: 'runSql never runs');
      expect(api.authPatches, isEmpty, reason: 'Auth is never changed');
      expect(api.deployed, isEmpty, reason: 'nothing is deployed');
    });

    test('an unconfigured endpoint exits 1 and names the check', () async {
      final (code, text) = await run(
        ['mcp-inspect', ...target1],
        target(),
        FakeHttp(anonymousStatus: 503),
      );
      expect(code, 1);
      expect(text, contains('endpoint_not_configured'));
    });

    test(
      '--json is the sanitized report, verifiable for this target only',
      () async {
        final (code, text) = await run([
          'mcp-inspect',
          ...target1,
          '--json',
        ], target());
        expect(code, 0);
        final report = jsonDecode(text) as Map<String, Object?>;
        expect(
          verifyMcpReadinessReport(
            report,
            ref: fixtureRef,
            installationId: fixtureInstallation,
            epoch: 1,
          ),
          isNull,
        );
        expect(
          verifyMcpReadinessReport(
            report,
            ref: 'zzzzzzzzzzzzzzzzzzzz',
            installationId: fixtureInstallation,
            epoch: 1,
          ),
          'report_for_other_target',
        );
      },
    );

    test('the only POST is anonymous and carries no credential', () async {
      final http = FakeHttp();
      await run(['mcp-inspect', ...target1], target(), http);
      expect(http.posts, hasLength(1));
      expect(http.posts.single.$3.keys, isNot(contains('Authorization')));
    });
  });

  group('mcp-enable', () {
    test('without --apply: a dry run that writes nothing', () async {
      final api = target();
      final (code, text) = await run([
        'mcp-enable',
        ...exact,
        '--epoch',
        '1',
      ], api);
      expect(code, 0);
      expect(text, contains('dry run: would enable'));
      expect(writes(api), isEmpty);
    });

    test('--apply hands the database the installation, epoch and evidence just measured', () async {
      final api = target();
      final (code, text) = await run([
        'mcp-enable',
        ...exact,
        '--epoch',
        '1',
        '--apply',
      ], api);
      expect(code, 0, reason: text);
      expect(writes(api), [
        "select public.operator_activate_mcp_runtime('$fixtureInstallation'::uuid, 1, '$fixtureFingerprint')::text as result",
      ]);
      expect(text, contains('mcp-pilot'));
    });

    test('another installation or epoch is refused before any write', () async {
      final api = target();
      final (c1, t1) = await run([
        'mcp-enable',
        '--ref',
        fixtureRef,
        '--installation',
        '00000000-0000-4000-8000-00000000000b',
        '--epoch',
        '1',
        '--apply',
      ], api);
      expect(c1, 1);
      expect(t1, contains('target_mismatch'));
      final (c2, t2) = await run([
        'mcp-enable',
        ...exact,
        '--epoch',
        '2',
        '--apply',
      ], api);
      expect(c2, 1);
      expect(t2, contains('epoch_mismatch'));
      expect(writes(api), isEmpty);
    });

    test(
      'a target that is not ready is refused with its codes, before any write',
      () async {
        final api = target();
        final (code, text) = await run(
          ['mcp-enable', ...exact, '--epoch', '1', '--apply'],
          api,
          FakeHttp(anonymousStatus: 503),
        );
        expect(code, 1);
        expect(text, contains('refused: not ready — endpoint_fails_closed'));
        expect(writes(api), isEmpty);
      },
    );

    test('the database refusing stale evidence is exit 1', () async {
      final api = target(
        refuse: 'MCP stays off: the readiness evidence is stale; inspect again',
      );
      final (code, text) = await run([
        'mcp-enable',
        ...exact,
        '--epoch',
        '1',
        '--apply',
      ], api);
      expect(code, 1);
      expect(
        text,
        contains(
          'refused by the database: MCP stays off: the readiness evidence is stale',
        ),
      );
    });

    test(
      'already on and verified: exit 0, nothing written (idempotent)',
      () async {
        final api = target(database: readyDatabase(enabled: true));
        final (code, text) = await run([
          'mcp-enable',
          ...exact,
          '--epoch',
          '1',
          '--apply',
        ], api);
        expect(code, 0);
        expect(text, contains('already on'));
        expect(writes(api), isEmpty);
      },
    );
  });

  group('mcp-pilot', () {
    Map<String, Object?> answer(Map<String, Object?> data) => {
      'result': {
        'isError': false,
        'structuredContent': {
          'operation': 'get_capabilities',
          'workspace_id': ws,
          'status': 'completed',
          'data': data,
        },
      },
    };

    test('refused while MCP is off; nothing is called', () async {
      final http = FakeHttp();
      final (code, text) = await run(
        ['mcp-pilot', ...exact, '--workspace', ws],
        target(),
        http,
      );
      expect(code, 1);
      expect(text, contains('needs MCP ON'));
      expect(http.posts, isEmpty);
    });

    test('a minimized answer passes and writes nothing', () async {
      final api = target(database: readyDatabase(enabled: true));
      final http = FakeHttp(
        pilotAnswer: answer({
          'operations': <String>[],
          'target_ceiling': 'own',
        }),
      );
      final (code, text) = await run(
        ['mcp-pilot', ...exact, '--workspace', ws],
        api,
        http,
      );
      expect(code, 0, reason: text);
      expect(writes(api), isEmpty);
      expect(
        http.posts.every(
          (p) => p.$3['Authorization'] == 'Bearer PRIVATE-PILOT-TOKEN',
        ),
        isTrue,
      );
    });

    test('a failed pilot switches MCP off, and says guards and audit stay', () async {
      final api = target(database: readyDatabase(enabled: true));
      final http = FakeHttp(
        pilotAnswer: answer({'operations': <String>[], 'email': 'x'}),
      );
      final (code, text) = await run(
        ['mcp-pilot', ...exact, '--workspace', ws],
        api,
        http,
      );
      expect(code, 1);
      expect(text, contains('switching MCP off'));
      expect(writes(api), [
        "select public.operator_disable_mcp_runtime('$fixtureInstallation'::uuid, 'pilot_failed')::text as result",
      ]);
    });
  });

  group('rollback and recovery', () {
    test('disable: a dry run by default, then a reasoned write and a native re-check', () async {
      final api = target(database: readyDatabase(enabled: true));
      final (c0, t0) = await run([
        'mcp-disable',
        ...exact,
        '--reason',
        'rollback',
      ], api);
      expect(c0, 0);
      expect(t0, contains('dry run'));
      expect(writes(api), isEmpty);
      final (c1, t1) = await run([
        'mcp-disable',
        ...exact,
        '--reason',
        'rollback',
        '--apply',
      ], api);
      expect(c1, 0, reason: t1);
      expect(
        writes(api).single,
        contains(
          "operator_disable_mcp_runtime('$fixtureInstallation'::uuid, 'rollback')",
        ),
      );
      expect(t1, contains('native access after this step: pass'));
    });

    test('reset is refused while MCP is on: disable first', () async {
      final api = target(database: readyDatabase(enabled: true));
      final (code, text) = await run([
        'mcp-reset',
        ...exact,
        '--reason',
        'restore drill',
        '--apply',
      ], api);
      expect(code, 1);
      expect(text, contains('mcp-disable --reason rollback --apply'));
      expect(writes(api), isEmpty);
    });

    test(
      'reset with MCP off moves the epoch and names the operator\'s next steps',
      () async {
        final api = target();
        final (code, text) = await run([
          'mcp-reset',
          ...exact,
          '--reason',
          "restore of last night's backup",
          '--apply',
        ], api);
        expect(code, 0, reason: text);
        expect(
          writes(api).single,
          contains("'restore of last night''s backup'"),
        );
        expect(text, contains('DESKILO_MCP_EPOCH'));
        expect(text, contains('db-admins --ref $fixtureRef grant'));
        expect(text, contains('(epoch 2)'));
      },
    );
  });

  group('the command line refuses before touching anything', () {
    final cases = <(String, List<String>, Map<String, String>)>[
      ('no ref', ['mcp-inspect'], env),
      ('an ambiguous ref', ['mcp-inspect', '--ref', 'prod'], env),
      (
        'two refs',
        ['mcp-inspect', '--ref', fixtureRef, '--ref', fixtureRef],
        env,
      ),
      (
        'a token in the arguments',
        ['mcp-inspect', '--ref', fixtureRef, '--token', 'PRIVATE-ARG'],
        env,
      ),
      (
        'no installation for enable',
        ['mcp-enable', '--ref', fixtureRef, '--epoch', '1'],
        env,
      ),
      (
        'an unknown reason',
        ['mcp-disable', ...exact, '--reason', 'because'],
        env,
      ),
      ('no management token', ['mcp-inspect', ...target1], const {}),
      (
        'a pilot without its token',
        ['mcp-pilot', ...exact, '--workspace', ws],
        const {'SUPABASE_ACCESS_TOKEN': 'PRIVATE-MANAGEMENT-TOKEN'},
      ),
    ];
    for (final (name, argv, environment) in cases) {
      test('$name → exit 2', () async {
        final api = target(database: readyDatabase(enabled: true));
        final out = _Out();
        final code = await runMcp(
          argv,
          environment: environment,
          api: api,
          http: FakeHttp(),
          release: (_) => fixtureRelease(),
          out: out,
        );
        expect(code, 2, reason: '${out.text}');
        expect('${out.text}', isNot(contains('PRIVATE')));
        expect(writes(api), isEmpty);
      });
    }
  });

  test(
    'the real process: a wrong command line exits 2 without echoing a secret',
    () async {
      for (final args in [
        ['mcp-inspect', '--ref', fixtureRef, '--token', 'PRIVATE-ARG-TOKEN'],
        [
          'mcp-enable',
          '--ref',
          fixtureRef,
          '--installation',
          'not-a-uuid',
          '--epoch',
          '1',
        ],
      ]) {
        final r = await Process.run(
          'dart',
          ['run', 'tool/instance.dart', ...args],
          environment: {'SUPABASE_ACCESS_TOKEN': 'PRIVATE-ENV-TOKEN'},
        );
        expect(r.exitCode, 2, reason: '${r.stdout}${r.stderr}');
        expect('${r.stdout}${r.stderr}', isNot(contains('PRIVATE')));
      }
    },
  );

  test('the release this checkout is: the catalogue the migrations install, the Edge classification', () {
    final release = loadMcpRelease('.');
    final migrations =
        Directory('supabase/migrations')
            .listSync()
            .whereType<File>()
            .where(
              (f) => f.readAsStringSync().contains(
                'create or replace function public.mcp_operation_catalogue()',
              ),
            )
            .map((f) => f.path)
            .toList()
          ..sort();
    final sql = File(migrations.last).readAsStringSync();
    final json = RegExp(
      r'\$json\$(.*?)\$json\$',
      dotAll: true,
    ).firstMatch(sql)!.group(1)!;
    expect(canonicalJson(release.catalogue), canonicalJson(jsonDecode(json)));
    expect(release.classifiedFunctions, contains('deskilo-mcp'));
    expect(
      release.contractLines.where(
        (l) => l.startsWith('routine public.mcp_pre_request()'),
      ),
      hasLength(1),
    );
  });
}
