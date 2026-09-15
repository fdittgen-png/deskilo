// SPDX-License-Identifier: 0BSD
//
// #1075 — the doctor, driven by the shapes it exists to catch.
//
// Every case below is a state the live project was actually in between
// 2026-09-06 and 2026-09-10, so a passing suite here means the check
// would have spoken on the 7th instead of a member asking on WhatsApp on
// the 10th.
import 'package:deskilo/core/instance/instance_builder.dart';
import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:deskilo/core/instance/management_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_supabase_management.dart';

/// The project as the wizard leaves it.
Map<String, Object?> healthyConfig() => {
      'site_url': InstanceAuthConfig.siteUrl,
      'uri_allow_list': InstanceAuthConfig.redirectAllowList,
      'mailer_autoconfirm': false,
    };

List<Map<String, Object?>> counts({
  int created7d = 0,
  int confirmed7d = 0,
  int stuck = 0,
  int oldestStuckHours = 0,
}) =>
    [
      {
        'created_7d': created7d,
        'confirmed_7d': confirmed7d,
        'stuck': stuck,
        'oldest_stuck_hours': oldestStuckHours,
      }
    ];

DoctorFinding named(List<DoctorFinding> all, String fragment) =>
    all.firstWhere((f) => f.title.contains(fragment));

void main() {
  _installChecks();
  _probeIsolation();
  group('auth configuration', () {
    test('the wizard-configured project is clean', () {
      final findings = InstanceDoctor.checkAuthConfig(healthyConfig());
      expect(findings.any((f) => f.isProblem), isFalse);
    });

    test('a localhost Site URL is an ALARM, not a warning', () {
      // The exact state of the live project: the mail says
      // http://localhost:3000, which is nobody's machine.
      final findings = InstanceDoctor.checkAuthConfig({
        ...healthyConfig(),
        'site_url': 'http://localhost:3000',
      });
      final finding = named(findings, 'Site URL');
      expect(finding.level, DoctorLevel.alarm);
      expect(finding.detail, contains('http://localhost:3000'));
      expect(finding.detail, contains('tool/instance.dart auth'),
          reason: 'a finding that does not say what to do costs a second '
              'investigation');
    });

    test('a Site URL that is merely different is a warning', () {
      final findings = InstanceDoctor.checkAuthConfig({
        ...healthyConfig(),
        'site_url': 'https://example.test/',
      });
      expect(named(findings, 'Site URL').level, DoctorLevel.warn);
    });

    test('a callback missing from the allow-list is an ALARM', () {
      // Supabase refuses an unlisted redirect and substitutes the Site
      // URL — so this fails even when the client asks for the right thing.
      final findings = InstanceDoctor.checkAuthConfig({
        ...healthyConfig(),
        'uri_allow_list': 'https://fdittgen-png.github.io/deskilo/**',
      });
      final finding = named(findings, 'allow-list');
      expect(finding.level, DoctorLevel.alarm);
      expect(finding.detail, contains('deskilo://**'));
    });

    test('autoconfirm is reported either way — it is never itself a fault',
        () {
      for (final on in [true, false]) {
        final findings = InstanceDoctor.checkAuthConfig(
            {...healthyConfig(), 'mailer_autoconfirm': on});
        final finding = named(findings, 'Confirmation e-mail');
        expect(finding.level, DoctorLevel.ok);
        expect(finding.detail, contains(on ? 'ON' : 'OFF'));
      }
    });

    test('an empty config does not throw — it reports', () {
      final findings = InstanceDoctor.checkAuthConfig(const {});
      expect(findings.any((f) => f.isProblem), isTrue);
    });
  });

  group('sign-ups', () {
    test('people arriving and nobody confirming is the alarm', () {
      // 2026-09-07 to 09: three created, zero confirmed. This is the
      // invariant that broke, and the one nothing was watching.
      final findings =
          InstanceDoctor.checkSignups(counts(created7d: 3, confirmed7d: 0));
      final finding = named(findings, 'Nobody has confirmed');
      expect(finding.level, DoctorLevel.alarm);
      expect(finding.detail, contains('3 signed up, 0 confirmed'));
    });

    test('zero sign-ups and zero confirmations is quiet, not an alarm', () {
      // A workspace nobody joined this week is not broken.
      final findings = InstanceDoctor.checkSignups(counts());
      expect(findings.any((f) => f.isProblem), isFalse);
    });

    test('stuck accounts are counted and aged', () {
      final findings = InstanceDoctor.checkSignups(
          counts(created7d: 3, confirmed7d: 1, stuck: 3, oldestStuckHours: 72));
      final finding = named(findings, 'cannot get in');
      expect(finding.level, DoctorLevel.alarm);
      expect(finding.detail, contains('72 h'));
    });

    test('one stuck account warns; several is an alarm', () {
      expect(
        named(InstanceDoctor.checkSignups(counts(created7d: 2, confirmed7d: 1, stuck: 1)),
                'cannot get in')
            .level,
        DoctorLevel.warn,
      );
      expect(
        named(InstanceDoctor.checkSignups(counts(created7d: 5, confirmed7d: 1, stuck: 3)),
                'cannot get in')
            .level,
        DoctorLevel.alarm,
      );
    });

    test('counts that arrive as strings are read, not ignored', () {
      // The Management API returns JSON; a bigint can come back quoted,
      // and a silently-zero count is a check that says everything is fine.
      final findings = InstanceDoctor.checkSignups([
        {'created_7d': '3', 'confirmed_7d': '0', 'stuck': '3',
          'oldest_stuck_hours': '72'}
      ]);
      expect(named(findings, 'Nobody has confirmed').level, DoctorLevel.alarm);
      expect(named(findings, 'cannot get in').detail, contains('72 h'));
    });

    test('no rows is a warning, never a green tick', () {
      expect(InstanceDoctor.checkSignups(const []).single.level,
          DoctorLevel.warn);
    });
  });

  group('the report', () {
    test('a healthy project says so and flags nothing', () {
      final findings = [
        ...InstanceDoctor.checkAuthConfig(healthyConfig()),
        ...InstanceDoctor.checkSignups(counts(created7d: 2, confirmed7d: 2)),
      ];
      expect(hasProblem(findings), isFalse);
      expect(doctorReport('abc', findings), contains('healthy'));
    });

    test('the 2026-09-09 state reports every fault at once', () {
      final findings = [
        ...InstanceDoctor.checkAuthConfig({
          'site_url': 'http://localhost:3000',
          'uri_allow_list': '',
          'mailer_autoconfirm': false,
        }),
        ...InstanceDoctor.checkSignups(
            counts(created7d: 3, confirmed7d: 0, stuck: 3, oldestStuckHours: 72)),
      ];
      expect(hasProblem(findings), isTrue);
      final report = doctorReport('zwzbynivewivvjmripeb', findings);
      expect(report, contains('ALARM'));
      expect(report, contains('localhost:3000'));
      expect(report, contains('3 signed up, 0 confirmed'));
      expect(report, contains('need a human'));
    });
  });
}

// ---------------------------------------------------------------------
// #1245 — the install, not just the sign-in.
//
// Every check below is one the repository already makes on a database CI
// builds (#1226). An operator running DesKilo on their own Supabase has
// neither the lints nor the pgTAP suite, so the doctor asks the same
// questions of the live project.
void _installChecks() {
  Map<String, Object?> row({
    int migrations = 214,
    int tables = 55,
    String noRls = '',
    String openPolicyless = '',
    String anonDefiners = '',
    String buckets = 'avatars, floor-plans',
  }) =>
      {
        'migrations_applied': migrations,
        'tables': tables,
        'tables_without_rls': noRls,
        'open_policyless': openPolicyless,
        'anon_definers': anonDefiners,
        'buckets': buckets,
      };

  List<DoctorFinding> examine(Map<String, Object?> r) =>
      InstanceDoctor.checkInstall([r]);

  DoctorFinding named(List<DoctorFinding> fs, String needle) =>
      fs.firstWhere((f) => f.title.contains(needle));

  group('the install doctor', () {
    test('a healthy install reports no problem at all', () {
      final findings = examine(row());
      expect(findings.where((f) => f.isProblem), isEmpty,
          reason: findings.join('\n'));
    });

    test('an empty project is an ALARM and says which command fixes it', () {
      final f = named(examine(row(migrations: 0, tables: 0)), 'Schema');
      expect(f.level, DoctorLevel.alarm);
      expect(f.detail, contains('instance.dart install'));
    });

    test('a half-installed schema is an alarm — it fails at the first '
        'feature whose table is missing and says nothing until then', () {
      final f = named(examine(row(migrations: 40, tables: 12)), 'Schema');
      expect(f.level, DoctorLevel.alarm);
      expect(f.detail, contains('40 migrations'));
    });

    test('MORE migrations than the floor is fine — a project may carry a '
        'hand-applied fix, and refusing to start over that would be the '
        'doctor causing the outage', () {
      expect(examine(row(migrations: 9001)).where((f) => f.isProblem), isEmpty);
    });

    test('a table without RLS is an alarm, named', () {
      final f = named(examine(row(noRls: 'invoices, ledger_entries')), 'Row-level');
      expect(f.level, DoctorLevel.alarm);
      expect(f.detail, contains('ledger_entries'));
    });

    test('a policy-less table that still grants to anon is a warning — '
        'nothing leaks today, and one create policy would', () {
      final f = named(
          examine(row(openPolicyless: 'payment_credentials')), 'no policy');
      expect(f.level, DoctorLevel.warn);
      expect(f.detail, contains('payment_credentials'));
    });

    test('a definer function callable by anon is an alarm — the EXECUTE '
        'grant is the only thing between anon and the whole database', () {
      final f = named(examine(row(anonDefiners: 'export_my_data')), 'DEFINER');
      expect(f.level, DoctorLevel.alarm);
      expect(f.detail, contains('export_my_data'));
    });

    test('a missing storage bucket is an alarm, and names the one', () {
      final f = named(examine(row(buckets: 'avatars')), 'bucket');
      expect(f.level, DoctorLevel.alarm);
      expect(f.detail, contains('floor-plans'));
      expect(f.detail, isNot(contains('avatars')),
          reason: 'only the MISSING one is named');
    });

    test('no rows is an alarm on each half, because that is a project that '
        'did not answer rather than a healthy one', () {
      expect(InstanceDoctor.checkSchema(const []).single.level, DoctorLevel.alarm);
      final security = InstanceDoctor.checkSecurity(const []).single;
      expect(security.level, DoctorLevel.alarm);
      expect(security.detail, contains('nothing about RLS'));
    });

    test('#1314 — tables without recorded migrations are named, with the '
        'remedy, instead of "no migration has ever run"', () {
      final f = named(examine(row(migrations: -1, tables: 55)), 'not recorded');
      expect(f.level, DoctorLevel.warn);
      expect(f.detail, contains('55 tables'));
      expect(f.detail, contains('instance.dart record --ref'));
    });

    test('#1314 — no migrations table and no tables is still the empty '
        'project', () {
      final f = named(examine(row(migrations: -1, tables: 0)), 'Schema');
      expect(f.level, DoctorLevel.alarm);
      expect(f.detail, contains('instance.dart install'));
    });
  });
}

// ---------------------------------------------------------------------
// #1314 — one question failing never silences the others.
//
// The install used to be asked in the same statement as the security
// checks, and that statement read `supabase_migrations`. On a project
// without it the query raised, `examine` returned nothing at all, and a
// real RLS problem sat behind a bookkeeping error.
void _probeIsolation() {
  group('the doctor asks each question on its own', () {
    test('a failing schema query leaves auth, sign-ups and security '
        'standing', () async {
      final api = FakeSupabaseManagement()
        ..authConfigValue = healthyConfig()
        ..failQueryContaining = 'supabase_migrations'
        ..failMessage =
            'relation "supabase_migrations.schema_migrations" does not exist';
      api.onQuery = (ref, sql) => sql == InstanceDoctor.securityHealthSql
          ? [
              {
                'tables_without_rls': 'invoices',
                'open_policyless': '',
                'anon_definers': '',
                'buckets': 'avatars, floor-plans',
              },
            ]
          : counts(created7d: 1, confirmed7d: 1);

      final findings = await InstanceDoctor(api).examine('ref-1');

      final failed = named(findings, 'Schema query failed');
      expect(failed.level, DoctorLevel.alarm);
      expect(failed.detail, contains('does not exist'));
      expect(named(findings, 'Row-level').level, DoctorLevel.alarm,
          reason: 'the real problem is still reported');
      expect(named(findings, 'Site URL').level, DoctorLevel.ok);
      expect(named(findings, 'Sign-ups').level, DoctorLevel.ok);
    });

    test('a token that cannot read the project stops the doctor once, as '
        'the CLI reports it', () async {
      final api = FakeSupabaseManagement()
        ..authConfigValue = healthyConfig()
        ..unauthorized = true;
      await expectLater(
        InstanceDoctor(api).examine('ref-1'),
        throwsA(isA<ManagementApiException>()
            .having((e) => e.unauthorized, 'unauthorized', isTrue)),
      );
    });
  });
}
