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
import 'package:flutter_test/flutter_test.dart';

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
