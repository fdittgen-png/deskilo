// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The release train's installation gate: three answers, and only "ready"
// publishes. An installation that is behind stops the train and names the
// missing migrations; one that times out, refuses the key, answers something
// that is not a number or has no version marker never passes. The candidate's
// requirement is read from its own tree, the track's installation from the
// committed map, and every upload leg of the train waits for the gate.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/backend/backend_config.dart';
import 'package:deskilo/core/instance/app_compatibility.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/release_gate/gate.dart';
import '../helpers/tool_process.dart';

const CandidateNeeds _needs = (
  schema: 12,
  builtAgainst: 12,
  app: 3,
  migrations: [
    (number: 10, file: '0010_a.sql'),
    (number: 11, file: '0011_b.sql'),
    (number: 12, file: '0012_c.sql'),
  ],
);

GateResult _judge(
  ProbeAnswer schema, [
  ProbeAnswer floor = const Answered(null),
]) => judgeInstallation(needs: _needs, schema: schema, floor: floor);

void main() {
  group('the verdict', () {
    test('a current installation with no floor is ready', () {
      final r = _judge(const Answered(12));
      expect(r.verdict, ReleaseVerdict.sufficient);
      expect(r.missing, isEmpty);
    });

    test('a newer installation is ready too', () {
      expect(
        _judge(const Answered(15), const Answered(2)).verdict,
        ReleaseVerdict.sufficient,
      );
    });

    test('a behind installation is insufficient and names exactly the missing migrations', () {
      final r = _judge(const Answered(10));
      expect(r.verdict, ReleaseVerdict.insufficient);
      expect(r.missing.map((m) => m.file), ['0011_b.sql', '0012_c.sql']);
    });

    test('an installation without the version marker is insufficient', () {
      final r = _judge(const MissingFunction());
      expect(r.verdict, ReleaseVerdict.insufficient);
      expect(r.missing, hasLength(3));
    });

    test('a floor above the candidate refuses it', () {
      final r = _judge(const Answered(12), const Answered(4));
      expect(r.verdict, ReleaseVerdict.insufficient);
      expect(r.reasons.join(), contains('accepts apps from 4'));
    });

    test('a floor at the candidate accepts it; a missing floor function is no floor', () {
      expect(
        _judge(const Answered(12), const Answered(3)).verdict,
        ReleaseVerdict.sufficient,
      );
      expect(
        _judge(const Answered(12), const MissingFunction()).verdict,
        ReleaseVerdict.sufficient,
      );
    });

    for (final (name, answer) in [
      ('a timeout', const Unreadable('TimeoutException')),
      ('a 401', const Unreadable('HTTP 401')),
      ('a body that is not a number', const Answered('12')),
      ('a version never recorded', const Answered(null)),
      ('a list', const Answered([12])),
    ]) {
      test('$name is not verified, never ready', () {
        expect(_judge(answer).verdict, ReleaseVerdict.unverified);
      });
    }

    test(
      'an unreadable floor is not verified even when the schema is current',
      () {
        expect(
          _judge(const Answered(12), const Unreadable('HTTP 500')).verdict,
          ReleaseVerdict.unverified,
        );
        expect(
          _judge(const Answered(12), const Answered('x')).verdict,
          ReleaseVerdict.unverified,
        );
      },
    );

    test('proven behind wins over unverified: the missing migrations are still named', () {
      final r = _judge(const Answered(11), const Unreadable('HTTP 503'));
      expect(r.verdict, ReleaseVerdict.insufficient);
      expect(r.missing.map((m) => m.file), ['0012_c.sql']);
    });

    test('only ready exits zero', () {
      expect(ReleaseVerdict.values.where((v) => v.exitCode == 0), [
        ReleaseVerdict.sufficient,
      ]);
    });
  });

  group('what the candidate needs', () {
    test('is read from its own tree: the constants the app compiles in', () {
      final needs = readCandidateNeeds(Directory.current);
      expect(
        needs.schema,
        appNeedsSchemaVersion,
        reason: 'what the app cannot work without (#3729)',
      );
      expect(needs.builtAgainst, requiredSchemaVersion);
      expect(needs.app, appCompatibilityNumber);
      expect(needs.migrations.last.number, requiredSchemaVersion);
    });

    test(
      'a candidate from before the split needs what it was built against',
      () {
        final tmp = Directory.systemTemp.createTempSync('gate-old');
        addTearDown(() => tmp.deleteSync(recursive: true));
        File('${tmp.path}/lib/core/instance/schema_compatibility.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync('const int requiredSchemaVersion = 12;\n');
        File('${tmp.path}/lib/core/instance/app_compatibility.dart')
            .writeAsStringSync('const int appCompatibilityNumber = 3;\n');
        final needs = readCandidateNeeds(tmp);
        expect(needs.schema, 12);
        expect(needs.builtAgainst, 12);
      },
    );

    test('an installation between needs and built-against is ready, and one '
        'below needs names only the migrations up to it', () {
      const split = (
        schema: 11,
        builtAgainst: 12,
        app: 3,
        migrations: [
          (number: 10, file: '0010_a.sql'),
          (number: 11, file: '0011_b.sql'),
          (number: 12, file: '0012_c.sql'),
        ],
      );
      expect(
        judgeInstallation(
          needs: split,
          schema: const Answered(11),
          floor: const Answered(null),
        ).verdict,
        ReleaseVerdict.sufficient,
      );
      final behind = judgeInstallation(
        needs: split,
        schema: const Answered(9),
        floor: const Answered(null),
      );
      expect(behind.verdict, ReleaseVerdict.insufficient);
      expect([for (final m in behind.missing) m.number], [10, 11]);
    });

    test('a tree without the declaration is refused, never assumed', () {
      final tmp = Directory.systemTemp.createTempSync('gate-empty');
      addTearDown(() => tmp.deleteSync(recursive: true));
      expect(() => readCandidateNeeds(tmp), throwsFormatException);
    });
  });

  group('the installation a track ships to', () {
    final map = File('contracts/release/installations.json').readAsStringSync();
    final train = loadYaml(
      File('.github/workflows/release-train.yml').readAsStringSync(),
    ) as YamlMap;
    final tracks =
        ((((train['on'] ?? train[true]) as YamlMap)['workflow_dispatch']
                    as YamlMap)['inputs']
                as YamlMap)['track']
            as YamlMap;

    test('every track the train offers is named', () {
      for (final track in tracks['options'] as YamlList) {
        expect(
          () => installationFor(map, '$track'),
          returnsNormally,
          reason: '$track',
        );
      }
      expect(() => installationFor(map, 'alpha1'), throwsFormatException);
    });

    test('is the server the release builds compile in', () {
      // No release leg passes a server of its own, so each track ships to the
      // compiled-in reference installation. A leg that starts passing one
      // must change the map with it.
      for (final leg in [
        'play-internal.yml',
        'ios-testflight.yml',
        'macos-app.yml',
        'windows-msi.yml',
        'web.yml',
      ]) {
        expect(
          File('.github/workflows/$leg').readAsStringSync(),
          isNot(contains('SUPABASE_URL')),
          reason: leg,
        );
      }
      for (final track in tracks['options'] as YamlList) {
        final i = installationFor(map, '$track');
        expect(i.url, BackendConfig.referenceUrl, reason: '$track');
        expect(i.key, BackendConfig.referenceKey, reason: '$track');
      }
    });

    test('plain http is refused except on the loopback', () {
      String one(String url) => jsonEncode({
        'tracks': {
          'alpha': {'installation': 'x', 'url': url, 'key': 'k'},
        },
      });
      expect(
        () => installationFor(one('http://example.org'), 'alpha'),
        throwsFormatException,
      );
      expect(
        installationFor(one('http://127.0.0.1:9'), 'alpha').url,
        'http://127.0.0.1:9',
      );
    });
  });

  group('the train', () {
    final train = loadYaml(
      File('.github/workflows/release-train.yml').readAsStringSync(),
    ) as YamlMap;
    final jobs = train['jobs'] as YamlMap;

    test('reads the installation from the pinned candidate before any leg', () {
      final gate = jobs['installation'] as YamlMap;
      expect(gate['needs'], contains('resolve'));
      final steps = (gate['steps'] as YamlList).cast<YamlMap>();
      final checkout = steps.firstWhere(
        (s) => '${s['uses']}'.startsWith('actions/checkout'),
      );
      expect(
        (checkout['with'] as YamlMap)['ref'],
        r'${{ needs.resolve.outputs.sha }}',
      );
      final run = steps.map((s) => '${s['run'] ?? ''}').join('\n');
      expect(run, contains('git rev-parse HEAD'));
      expect(run, contains(r'dart tool/release_gate.dart --track "$TRACK"'));
      expect(
        run,
        contains(r'exit "$code"'),
        reason: 'the gate exit is the job result',
      );
      for (final leg in ['android', 'apple', 'macos', 'windows', 'web']) {
        expect(
          (jobs[leg] as YamlMap)['needs'],
          contains('installation'),
          reason: leg,
        );
        expect(
          '${(jobs[leg] as YamlMap)['if'] ?? ''}',
          isNot(contains('always')),
          reason: '$leg must not run past a failed gate',
        );
      }
    });

    test('reports the gate like a leg', () {
      final report = jobs['report'] as YamlMap;
      expect(report['needs'], contains('installation'));
      final run =
          ((report['steps'] as YamlList).first as YamlMap)['run'] as String;
      expect(run, contains('for leg in resolve installation '));
      expect(
        '${(jobs['installation'] as YamlMap)['name']}',
        startsWith('installation '),
        reason: 'the report finds a failed job by its leg name',
      );
    });
  });

  group('the command against an installation', () {
    late HttpServer server;
    late Directory root;
    var schema = '12';
    var schemaStatus = 200;
    var floor = 'null';
    var hang = false;

    setUp(() async {
      server = (await HttpServer.bind(InternetAddress.loopbackIPv4, 0))
        ..listen((req) async {
          await req.drain<void>();
          if (hang) return;
          final isSchema = req.uri.path.endsWith('/deskilo_schema_version');
          req.response
            ..statusCode = isSchema ? schemaStatus : 200
            ..write(isSchema ? schema : floor);
          await req.response.close();
        });
      root = Directory.systemTemp.createTempSync('gate-root');
      File('${root.path}/lib/core/instance/schema_compatibility.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('const int requiredSchemaVersion = 12;\n');
      File('${root.path}/lib/core/instance/app_compatibility.dart')
          .writeAsStringSync('const int appCompatibilityNumber = 3;\n');
      for (final f in ['0010_a.sql', '0011_b.sql', '0012_c.sql']) {
        File('${root.path}/supabase/migrations/$f').createSync(recursive: true);
      }
      File('${root.path}/contracts/release/installations.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            'tracks': {
              'alpha': {
                'installation': 'fixture',
                'url': 'http://127.0.0.1:${server.port}',
                'key': 'k',
              },
            },
          }),
        );
    });

    tearDown(() async {
      await server.close(force: true);
      root.deleteSync(recursive: true);
      schema = '12';
      schemaStatus = 200;
      floor = 'null';
      hang = false;
    });

    Future<ProcessResult> gate([String track = 'alpha']) => runTool(
      'tool/release_gate.dart',
      ['--track', track, '--root', root.path, '--timeout-seconds', '2'],
    );

    test('a current installation: exit 0', () async {
      final r = await gate();
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(r.stdout, contains('ready'));
    });

    test(
      'a behind installation: exit 1, the missing migrations named',
      () async {
        schema = '10';
        final r = await gate();
        expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
        expect(
          r.stdout,
          allOf(
            contains('0011_b.sql'),
            contains('0012_c.sql'),
            isNot(contains('0010_a.sql')),
          ),
        );
      },
    );

    test('a refused key: exit 2', () async {
      schemaStatus = 401;
      schema = '{"message":"Invalid API key"}';
      final r = await gate();
      expect(r.exitCode, 2, reason: '${r.stdout}${r.stderr}');
    });

    test('a missing version marker: exit 1', () async {
      schemaStatus = 404;
      schema = '{"code":"PGRST202","message":"Could not find the function"}';
      expect((await gate()).exitCode, 1);
    });

    test('a malformed answer: exit 2', () async {
      schema = '<html>maintenance</html>';
      expect((await gate()).exitCode, 2);
    });

    test('silence: exit 2 within the timeout', () async {
      hang = true;
      final r = await gate();
      expect(r.exitCode, 2, reason: '${r.stdout}${r.stderr}');
    });

    test('a track the map does not name: exit 2, nothing read', () async {
      expect((await gate('production')).exitCode, 2);
    });
  });
}
