// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The auth patch every instance gets: linking a Google (or other) account
// from Settings needs gotrue's manual linking switched on.
import 'package:deskilo/core/backend/auth_callback_guard.dart';
import 'package:deskilo/core/instance/instance_builder.dart';
import 'package:deskilo/core/instance/instance_doctor.dart';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_supabase_management.dart';
import '../../helpers/installation_auth_storage.dart' show MemorySecrets;

void main() {
  test('the auth patch turns manual identity linking on', () {
    expect(InstanceAuthConfig.patch['security_manual_linking_enabled'], true);
    expect(InstanceAuthConfig.patch['mailer_autoconfirm'], false);
  });

  group('#3904 — the sign-in baseline', () {
    const keys = {
      'password_min_length': 10,
      'security_update_password_require_reauthentication': true,
      'mailer_otp_exp': 900,
      'mailer_otp_length': 8,
      'mailer_secure_email_change_enabled': true,
      'security_refresh_token_reuse_interval': 10,
      'refresh_token_rotation_enabled': true,
      'rate_limit_otp': 30,
      'rate_limit_verify': 30,
    };

    test('every instance gets it, the web build included', () {
      final web = InstanceAuthConfig.patchForWebBase(Uri.parse('https://www.deskilo.org/app/'));
      for (final MapEntry(:key, :value) in keys.entries) {
        expect(InstanceAuthConfig.patch[key], value, reason: key);
        expect(web[key], value, reason: key);
      }
    });

    test('the doctor names codes kept over an hour, short passwords and a '
        'password change without signing in again', () {
      final weak = {
        ...InstanceAuthConfig.patch,
        'mailer_otp_exp': 86400,
        'password_min_length': 8,
        'security_update_password_require_reauthentication': false,
      };
      final findings = InstanceDoctor.checkAuthConfig(weak);
      final warned = {
        for (final f in findings)
          if (f.level == DoctorLevel.warn) f.words,
      };
      expect(warned, {
        DoctorWords.authCodesLong,
        DoctorWords.authPasswordShort,
        DoctorWords.authReauthOff,
      });
      expect(findings.map((f) => f.words), isNot(contains(DoctorWords.authBaseline)));
      expect(
        findings.firstWhere((f) => f.words == DoctorWords.authCodesLong).detail,
        allOf(contains('86400'), contains('tool/instance.dart auth')),
      );
    });

    test('the baseline itself is ok; an Auth version that reports none of it '
        'is not judged', () {
      final ok = InstanceDoctor.checkAuthConfig(InstanceAuthConfig.patch);
      expect(ok.where((f) => f.words == DoctorWords.authBaseline).single.level, DoctorLevel.ok);
      expect(ok.where((f) => f.level == DoctorLevel.warn), isEmpty);
      final silent = InstanceDoctor.checkAuthConfig({
        'site_url': InstanceAuthConfig.siteUrl,
        'uri_allow_list': InstanceAuthConfig.redirectAllowList,
      });
      expect(
        silent.where((f) => f.words?.name.startsWith('auth') ?? false),
        isEmpty,
      );
    });
  });

  test('web auth target uses the deployment origin and base path only', () {
    final patch = InstanceAuthConfig.patchForWebBase(
      Uri.parse('https://www.deskilo.org/app/?deskilo_flow=transient#/auth'),
    );
    expect(patch['site_url'], 'https://www.deskilo.org/app/');
    expect(
      patch['uri_allow_list'],
      'deskilo://**,https://www.deskilo.org/app/**',
    );
    expect(patch['security_manual_linking_enabled'], true);
  });

  test('custom deployment paths remain scoped and CLI default is unchanged', () {
    final patch = InstanceAuthConfig.patchForWebBase(
      Uri.parse('https://example.test:8443/coworking?temporary=x#route'),
    );
    expect(patch['site_url'], 'https://example.test:8443/coworking');
    expect(
      patch['uri_allow_list'],
      'deskilo://**,https://example.test:8443/coworking,https://example.test:8443/coworking/**',
    );
    expect(
      InstanceAuthConfig.patch['site_url'],
      'https://fdittgen-png.github.io/deskilo/',
    );
    expect(
      () => InstanceAuthConfig.patchForWebBase(
        Uri.parse('deskilo://auth-callback'),
      ),
      throwsArgumentError,
    );
    expect(
      () => InstanceAuthConfig.patchForWebBase(
        Uri.parse('https://user:pass@example.test/app/'),
      ),
      throwsArgumentError,
    );
    expect(
      () => InstanceAuthConfig.patchForWebBase(
        Uri.parse('https://example.test/app/*'),
      ),
      throwsArgumentError,
    );
    expect(
      () => InstanceAuthConfig.patchForWebBase(
        Uri.parse('https://example.test/app,other'),
      ),
      throwsArgumentError,
    );
    expect(
      () => InstanceAuthConfig.patchForWebBase(
        Uri.parse('https://example.test/%2a'),
      ),
      throwsArgumentError,
    );
  });

  test('deployment base covers a routed callback guard without adopting its flow', () async {
    final patch = InstanceAuthConfig.patchForWebBase(
      Uri.parse('https://example.test/app/'),
    );
    final guard = AuthCallbackGuard(
      MemorySecrets(),
      Uri.parse('https://auth.example.test'),
      Uri.parse('https://example.test/app/auth/reset'),
    );
    final redirect = Uri.parse(await guard.begin('social'));
    expect(redirect.path, '/app/auth/reset');
    expect(redirect.queryParameters['deskilo_flow'], isNotEmpty);
    expect(patch['site_url'], 'https://example.test/app/');
    expect(patch['uri_allow_list'], 'deskilo://**,https://example.test/app/**');
    expect(patch['uri_allow_list'] as String, isNot(contains(redirect.query)));
  });

  test('doctor shell-quotes the exact custom site safely', () {
    final patch = InstanceAuthConfig.patchForWebBase(
      Uri.parse("https://example.test/a'b/"),
    );
    final finding = InstanceDoctor.checkAuthConfig(
      InstanceAuthConfig.patch, expectedAuth: patch,
    ).firstWhere((f) => f.title == 'Site URL is not the app');
    expect(finding.detail, contains("--site-url 'https://example.test/a'\\''b/'"));
  });

  test(
    'builder and doctor use the same explicitly supplied web target',
    () async {
      final patch = InstanceAuthConfig.patchForWebBase(
        Uri.parse('https://example.test/coworking/?flow=temporary#page'),
      );
      final api = FakeSupabaseManagement();
      await InstanceBuilder(api).configureAuth('ref', authPatch: patch);
      expect(api.authPatches['ref']!.single, patch);
      final findings = InstanceDoctor.checkAuthConfig(
        patch,
        expectedAuth: patch,
      );
      expect(
        findings.where((f) => f.title == 'Site URL').single.level,
        DoctorLevel.ok,
      );
      expect(
        findings.where((f) => f.title == 'Redirect allow-list').single.level,
        DoctorLevel.ok,
      );
      final mismatch = InstanceDoctor.checkAuthConfig(
        InstanceAuthConfig.patch,
        expectedAuth: patch,
      );
      expect(
        mismatch.where((f) => f.title.contains('Site URL')).single.level,
        DoctorLevel.warn,
      );
      expect(
        mismatch.where((f) => f.title.contains('allow-list')).single.detail,
        contains("--site-url 'https://example.test/coworking/'"),
      );
    },
  );
}
