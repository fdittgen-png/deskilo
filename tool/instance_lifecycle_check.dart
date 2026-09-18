// SPDX-License-Identifier: 0BSD
//
// #1337 — the self-hosted lifecycle, proven against real databases rather
// than faked Management API answers.
//
// The install, the resume, the readiness verdict and the doctor were all
// tested with a fake that answers what the test says a project would. That
// proves the arithmetic, not the SQL: a `recordedVersionsSql` that raised on
// a real catalogue, a migration that forgot its marker, a probe that read a
// missing table would all pass. This runs the REAL InstanceBuilder,
// InstanceReadinessCheck and InstanceDoctor, unmodified, against databases
// in the local Supabase stack that start as an empty Supabase project
// (`scripts/instance_lifecycle_check.sh` prepares them), through
// `PsqlSupabaseManagement`.
//
//   dart run tool/instance_lifecycle_check.dart \
//     --psql "docker exec supabase_db_deskilo psql -U postgres" \
//     --install <empty db> --resume <empty db> --foreign <empty db>
//
// One line per scenario; exit 1 when any failed. Function deploys and auth
// settings are not covered: only a hosted project has them.
import 'dart:io';

import 'package:deskilo/core/instance/instance_builder.dart';
import 'package:deskilo/core/instance/instance_bundle.dart';
import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:deskilo/core/instance/instance_readiness.dart';

import 'build_instance.dart';
import 'instance_lifecycle/psql_management.dart';

class _Failed implements Exception {
  _Failed(this.message);
  final String message;
}

void _check(bool ok, String message) {
  if (!ok) throw _Failed(message);
}

String _versionOf(InstanceMigration m) => m.name.split('_').first;

/// A copy of [bundle] whose migration at [index] ends in a statement that
/// fails — after the migration's own statements, so they must roll back.
InstanceBundle _breaking(InstanceBundle bundle, int index) => InstanceBundle(
  schema: [
    for (var i = 0; i < bundle.schema.length; i++)
      i == index
          ? (
              name: bundle.schema[i].name,
              sql:
                  '${bundle.schema[i].sql.trimRight()}\n;\n'
                  "select 1 / 0 as interrupted_on_purpose;\n",
            )
          : bundle.schema[i],
  ],
  functions: bundle.functions,
);

Future<void> main(List<String> argv) async {
  // The VM ignores what main returns; the exit code is set, not returned.
  exitCode = await _run(argv);
}

Future<int> _run(List<String> argv) async {
  final options = <String, String>{};
  for (var i = 0; i + 1 < argv.length; i += 2) {
    if (argv[i].startsWith('--')) options[argv[i].substring(2)] = argv[i + 1];
  }
  final psql = options['psql']?.split(' ').where((s) => s.isNotEmpty).toList();
  final installDb = options['install'];
  final resumeDb = options['resume'];
  final foreignDb = options['foreign'];
  if (psql == null ||
      installDb == null ||
      resumeDb == null ||
      foreignDb == null) {
    stderr.writeln(
      'usage: dart run tool/instance_lifecycle_check.dart '
      '--psql "<psql command>" --install <db> --resume <db> --foreign <db>',
    );
    return 2;
  }

  final bundle = parseInstanceBundle(
    encodeInstanceBundle(buildInstanceBundle('.')),
  );
  final latest = int.parse(bundle.schemaVersion);
  final slugs = [for (final f in bundle.functions) f.slug];
  final expectedPolicies = {
    for (final line in File('assets/instance/policies.txt').readAsLinesSync())
      if (line.trim().isNotEmpty && !line.trim().startsWith('#')) line.trim(),
  };
  PsqlSupabaseManagement api() =>
      PsqlSupabaseManagement(psql: psql, functionSlugs: slugs);
  // Fixtures — a foreign table, a dropped bookkeeping table — go through
  // their own adapter, so the counted ones only see what the code sent.
  final fixture = api();

  Future<({int? marker, int recorded, List<String> versions})> recorded(
    PsqlSupabaseManagement on,
    String db,
  ) async {
    final row = (await on.query(db, InstanceBuilder.recordedVersionsSql)).first;
    return (
      marker: int.tryParse('${row['marker'] ?? ''}'),
      recorded: int.tryParse('${row['recorded'] ?? ''}') ?? 0,
      versions: '${row['versions'] ?? ''}'
          .split(',')
          .where((v) => v.isNotEmpty)
          .toList(),
    );
  }

  List<String> versionsThrough(int count) => [
    for (final m in bundle.schema.take(count)) _versionOf(m),
  ];

  Future<List<DoctorFinding>> doctor(PsqlSupabaseManagement on, String db) =>
      InstanceDoctor(on).examine(
        db,
        required: latest,
        bundleMigrations: [for (final m in bundle.schema) m.name],
        expectedPolicies: expectedPolicies,
      );

  String problems(List<DoctorFinding> findings) => [
    for (final f in findings)
      if (f.isProblem) '${f.level.name} ${f.title}: ${f.detail}',
  ].join('; ');

  var failures = 0;
  Future<void> scenario(String name, Future<String> Function() body) async {
    final watch = Stopwatch()..start();
    try {
      final detail = await body();
      stdout.writeln('ok    $name — $detail (${watch.elapsed.inSeconds}s)');
    } on Object catch (e) {
      failures++;
      final message = e is _Failed ? e.message : '$e';
      stdout.writeln('FAIL  $name — $message (${watch.elapsed.inSeconds}s)');
    }
  }

  // Marker readings between two migrations, for scenario 5.
  final markerAfter = <String, int?>{};
  Future<void> readMarker(String db, String sql) async {
    final version = recordedVersionOf(sql);
    if (version == null || int.parse(version) < 226) return;
    markerAfter[version] = (await recorded(fixture, db)).marker;
  }

  stdout.writeln(
    'instance lifecycle — ${bundle.schema.length} migrations, '
    'schema $latest, against real databases',
  );

  // ------------------------------------------------------------------ 1
  await scenario('empty project: install everything, doctor passes', () async {
    final a = api();
    final project = await a.project(installDb);
    final before = await InstanceReadinessCheck(a).examine(project, bundle);
    _check(
      before.verdict == InstanceReadinessVerdict.install,
      'an empty project reads as ${before.verdict} (${before.attention}), '
      'not install',
    );
    _check(
      before.pending == bundle.schema.length,
      'pending ${before.pending}, want ${bundle.schema.length}',
    );
    _check(a.mutations.isEmpty, 'the readiness check ran SQL that writes');

    await InstanceBuilder(a).installSchema(installDb, bundle);
    _check(
      a.mutations.length == bundle.schema.length,
      '${a.mutations.length} runSql calls for ${bundle.schema.length} '
      'migrations',
    );
    final state = await recorded(a, installDb);
    _check(state.marker == latest, 'marker ${state.marker}, want $latest');
    _check(
      state.recorded == bundle.schema.length,
      '${state.recorded} recorded, want ${bundle.schema.length}',
    );
    _check(
      state.versions.join(',') ==
          versionsThrough(bundle.schema.length).join(','),
      'recorded versions differ from the bundle',
    );

    final after = await InstanceReadinessCheck(a).examine(project, bundle);
    _check(
      after.verdict == InstanceReadinessVerdict.current && after.pending == 0,
      'after the install the verdict is ${after.verdict}, '
      'pending ${after.pending}',
    );

    final findings = await doctor(a, installDb);
    final schema = InstanceDoctor.checkSchema(
      await a.query(installDb, InstanceDoctor.schemaHealthSql),
      required: latest,
    );
    final security = InstanceDoctor.checkSecurity(
      await a.query(installDb, InstanceDoctor.securityHealthSql),
    );
    _check(!hasAlarm(schema), 'schema: ${problems(schema)}');
    _check(!hasAlarm(security), 'security: ${problems(security)}');
    _check(!hasProblem(findings), 'the doctor found: ${problems(findings)}');
    return '${a.mutations.length} migrations, marker ${state.marker}, '
        '${findings.length} doctor findings, none a problem';
  });

  // ------------------------------------------------------ 2, 3 and 5
  // Interrupted twice — once before the marker existed, once after — and
  // resumed each time from what the database says.
  // The early break lands on a migration that creates a table no earlier
  // one did and the finished schema still has — so "it rolled back" is
  // read from a table that would otherwise really be there.
  Future<(int, String)> tableCreatingMigration(int from) async {
    final seen = <String>{};
    for (var i = 0; i < bundle.schema.length; i++) {
      final created = bundleTables(
        InstanceBundle(schema: [bundle.schema[i]], functions: const []),
      );
      if (i >= from) {
        for (final table in created.difference(seen)) {
          final rows = await fixture.query(
            installDb,
            "select to_regclass('public.$table') is not null as present",
          );
          if (rows.first['present'] == true) return (i, table);
        }
      }
      seen.addAll(created);
    }
    throw _Failed('no migration from index $from creates a lasting table');
  }

  final (early, earlyTable) = await tableCreatingMigration(
    bundle.schema.length ~/ 2,
  );
  final late = bundle.schema.indexWhere((m) => int.parse(_versionOf(m)) >= 230);
  final ran = <String>[];

  await scenario(
    'interrupted install: nothing of the failed migration stays',
    () async {
      _check(late > early, 'the bundle has no migration 0230 after $early');
      final b = api();
      final broken = bundle.schema[early];
      final table = earlyTable;
      Object? stopped;
      try {
        await InstanceBuilder(b).installSchema(
          resumeDb,
          _breaking(bundle, early),
          onProgress: (p) {
            if (p.current.isNotEmpty) ran.add(p.current);
          },
        );
      } on InstanceStepFailure catch (e) {
        stopped = e;
      }
      _check(
        stopped is InstanceStepFailure && stopped.item == broken.name,
        'the install did not stop at ${broken.name}: $stopped',
      );
      ran.removeLast();
      _check(
        b.mutations.length == early + 1,
        '${b.mutations.length} runSql calls, want ${early + 1}',
      );
      final state = await recorded(b, resumeDb);
      _check(
        state.versions.join(',') == versionsThrough(early).join(','),
        'recorded ${state.recorded} versions, want the first $early',
      );
      _check(state.marker == null, 'a marker (${state.marker}) before 0226');
      final leftover = await b.query(
        resumeDb,
        "select to_regclass('public.$table') is not null as present",
      );
      _check(
        leftover.first['present'] == false,
        'public.$table survived the rolled-back ${broken.name}',
      );

      final verdict = await InstanceReadinessCheck(
        b,
      ).examine(await b.project(resumeDb), bundle);
      _check(
        verdict.verdict == InstanceReadinessVerdict.resume,
        'the verdict is ${verdict.verdict} (${verdict.attention}), not resume',
      );
      _check(
        verdict.pending == bundle.schema.length - early,
        'pending ${verdict.pending}, want ${bundle.schema.length - early}',
      );
      _check(b.mutations.length == early + 1, 'the readiness check ran SQL');
      return 'stopped at ${broken.name}, $early recorded, public.$table rolled '
          'back, verdict resume with ${verdict.pending} pending';
    },
  );

  await scenario(
    'resumed install stops again after the marker, marker holds',
    () async {
      final b = api()..afterRunSql = readMarker;
      final broken = bundle.schema[late];
      Object? stopped;
      final attempt = <String>[];
      try {
        await InstanceBuilder(b).installSchema(
          resumeDb,
          _breaking(bundle, late),
          onProgress: (p) {
            if (p.current.isNotEmpty) attempt.add(p.current);
          },
        );
      } on InstanceStepFailure catch (e) {
        stopped = e;
      }
      _check(
        stopped is InstanceStepFailure && stopped.item == broken.name,
        'the resume did not stop at ${broken.name}: $stopped',
      );
      _check(
        attempt.first == bundle.schema[early].name,
        'the resume started at ${attempt.first}, not '
        '${bundle.schema[early].name}',
      );
      attempt.removeLast();
      ran.addAll(attempt);
      _check(
        b.mutations.length == late - early + 1,
        '${b.mutations.length} runSql calls, want ${late - early + 1}',
      );
      final state = await recorded(b, resumeDb);
      final previous = int.parse(_versionOf(bundle.schema[late - 1]));
      _check(
        state.marker == previous,
        'marker ${state.marker} after a failed ${broken.name}, want $previous',
      );
      _check(
        state.versions.join(',') == versionsThrough(late).join(','),
        'recorded versions are not exactly the first $late',
      );
      return 'resumed at ${bundle.schema[early].name}, stopped at ${broken.name}, '
          'marker still $previous';
    },
  );

  await scenario(
    'schema at N: upgrade runs only N+1..latest, nothing twice',
    () async {
      final b = api()..afterRunSql = readMarker;
      final marker = int.parse(_versionOf(bundle.schema[late - 1]));
      final verdict = await InstanceReadinessCheck(
        b,
      ).examine(await b.project(resumeDb), bundle);
      _check(
        verdict.verdict == InstanceReadinessVerdict.upgrade,
        'the verdict is ${verdict.verdict} (${verdict.attention}), not upgrade',
      );
      _check(verdict.marker == marker, 'verdict marker ${verdict.marker}');
      _check(
        verdict.pending == latest - marker,
        'pending ${verdict.pending}, want ${latest - marker}',
      );
      final point = await InstanceBuilder(b).resumePoint(resumeDb, bundle);
      _check(point == late, 'resumePoint $point, want $late');

      final attempt = <String>[];
      await InstanceBuilder(b).installSchema(
        resumeDb,
        bundle,
        onProgress: (p) {
          if (p.current.isNotEmpty) attempt.add(p.current);
        },
      );
      _check(
        attempt.join(',') ==
            [for (final m in bundle.schema.skip(late)) m.name].join(','),
        'the upgrade ran ${attempt.length} migrations, not exactly the '
        '${bundle.schema.length - late} after $marker',
      );
      _check(
        b.mutations.length == attempt.length,
        '${b.mutations.length} runSql calls for ${attempt.length} migrations',
      );
      ran.addAll(attempt);
      final twice = ran.toSet().length != ran.length;
      _check(!twice, 'a migration ran twice across the three attempts');
      _check(
        ran.join(',') == [for (final m in bundle.schema) m.name].join(','),
        'the attempts together did not run the bundle once, in order',
      );
      final state = await recorded(b, resumeDb);
      _check(state.marker == latest, 'marker ${state.marker}, want $latest');
      _check(
        state.recorded == bundle.schema.length,
        '${state.recorded} recorded, want ${bundle.schema.length}',
      );
      final now = await InstanceReadinessCheck(
        b,
      ).examine(await b.project(resumeDb), bundle);
      _check(
        now.verdict == InstanceReadinessVerdict.current,
        'after the upgrade the verdict is ${now.verdict}',
      );
      return 'pending ${verdict.pending}, ran ${attempt.length}, every migration '
          'exactly once over three attempts, marker $latest';
    },
  );

  await scenario('every migration from 0226 writes its own marker', () async {
    final expected = [
      for (final m in bundle.schema)
        if (int.parse(_versionOf(m)) >= 226) _versionOf(m),
    ];
    final wrong = [
      for (final v in expected)
        if (markerAfter[v] != int.parse(v)) '$v→${markerAfter[v]}',
    ];
    _check(
      markerAfter.length == expected.length,
      'read the marker after ${markerAfter.length} of ${expected.length} '
      'migrations',
    );
    _check(wrong.isEmpty, 'marker after the migration: ${wrong.join(', ')}');
    return 'read after each of ${expected.first}..${expected.last}, each '
        'equal to its own number';
  });

  // ------------------------------------------------------------------ 4
  await scenario(
    'foreign table or unhealthy project: blocked, no SQL runs',
    () async {
      await fixture.runSql(
        foreignDb,
        'create table public.guestbook (id bigint primary key, note text);',
      );
      final c = api();
      final verdict = await InstanceReadinessCheck(
        c,
      ).examine(await c.project(foreignDb), bundle);
      _check(
        verdict.verdict == InstanceReadinessVerdict.needsAttention &&
            verdict.attention == InstanceAttention.foreignTables,
        'the verdict is ${verdict.verdict} (${verdict.attention})',
      );
      _check(
        verdict.foreignTables.join(',') == 'guestbook',
        'foreign tables named: ${verdict.foreignTables}',
      );
      _check(c.mutations.isEmpty, '${c.mutations.length} runSql calls');

      final down = api()..status = 'COMING_UP';
      final unhealthy = await InstanceReadinessCheck(
        down,
      ).examine(await down.project(foreignDb), bundle);
      _check(
        unhealthy.attention == InstanceAttention.notHealthy,
        'an unhealthy project reads as ${unhealthy.verdict} '
        '(${unhealthy.attention})',
      );
      _check(
        down.mutations.isEmpty && down.queries.isEmpty,
        'an unhealthy project was queried',
      );

      final left = await fixture.query(foreignDb, '''
select (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
         where n.nspname = 'public' and c.relkind = 'r') as tables,
       to_regnamespace('supabase_migrations') is not null as bookkeeping''');
      _check(
        left.first['tables'] == 1 && left.first['bookkeeping'] == false,
        'the blocked project changed: ${left.first}',
      );
      return 'needsAttention/foreignTables [guestbook], notHealthy, 0 runSql '
          'calls, the project unchanged';
    },
  );

  // ------------------------------------------------------------------ 6
  await scenario('doctor: a failing probe silences no other finding', () async {
    await fixture.runSql(
      installDb,
      'drop table supabase_migrations.schema_migrations;',
    );
    final d = api();
    final withoutBookkeeping = await doctor(d, installDb);
    final titles = {for (final f in withoutBookkeeping) f.title};
    const security = {
      'Row-level security',
      'Closed tables',
      'Definer functions',
      'Storage buckets',
    };
    _check(
      titles.containsAll(security),
      'security findings missing without bookkeeping: '
      '${security.difference(titles)}',
    );
    _check(
      !hasProblem(withoutBookkeeping),
      'without bookkeeping: ${problems(withoutBookkeeping)}',
    );
    final point = await InstanceBuilder(d).resumePoint(installDb, bundle);
    _check(
      point == bundle.schema.length,
      'without bookkeeping the marker should still say current: $point',
    );

    // And a probe that really fails: the marker itself raises. Its own
    // alarm, and every other finding still there.
    await fixture.runSql(installDb, r'''
create or replace function public.deskilo_schema_version()
returns int language plpgsql stable security invoker set search_path = public
as $$ begin raise exception 'the marker is withheld on purpose'; end $$;''');
    final broken = await doctor(d, installDb);
    final alarms = [
      for (final f in broken)
        if (f.level == DoctorLevel.alarm) f.title,
    ];
    _check(
      alarms.join(',') == 'Schema query failed',
      'with the marker raising the alarms are $alarms',
    );
    final still = {for (final f in broken) f.title};
    final others = {
      ...security,
      'Sign-ups (7 days)',
      'Policies match the migrations',
    };
    _check(
      still.containsAll(others),
      'a failed schema probe hid: ${others.difference(still)}',
    );
    return 'no bookkeeping: all ${withoutBookkeeping.length} findings, no '
        'problem; failed probe: one alarm, ${broken.length - 1} other findings';
  });

  stdout.writeln(
    failures == 0
        ? 'instance lifecycle: every scenario passed'
        : 'instance lifecycle: $failures scenario(s) failed',
  );
  return failures == 0 ? 0 : 1;
}
