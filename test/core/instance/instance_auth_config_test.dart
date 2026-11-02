// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The auth patch every instance gets: linking a Google (or other) account
// from Settings needs gotrue's manual linking switched on.
import 'package:deskilo/core/instance/instance_builder.dart';
import 'package:deskilo/core/instance/instance_doctor.dart';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_supabase_management.dart';

void main() {
  test('the auth patch turns manual identity linking on', () {
    expect(InstanceAuthConfig.patch['security_manual_linking_enabled'], true);
    expect(InstanceAuthConfig.patch['mailer_autoconfirm'], false);
  });

  test('web auth target uses the callback origin and path only', () {
    final patch = InstanceAuthConfig.patchForWebCallback(
      Uri.parse('https://www.deskilo.org/app/?deskilo_flow=transient#/auth'),
    );
    expect(patch['site_url'], 'https://www.deskilo.org/app/');
    expect(
      patch['uri_allow_list'],
      'deskilo://**,https://www.deskilo.org/app/**',
    );
    expect(patch['security_manual_linking_enabled'], true);
  });

  test('custom callback paths remain scoped and CLI default is unchanged', () {
    final patch = InstanceAuthConfig.patchForWebCallback(
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
      () => InstanceAuthConfig.patchForWebCallback(
        Uri.parse('deskilo://auth-callback'),
      ),
      throwsArgumentError,
    );
    expect(
      () => InstanceAuthConfig.patchForWebCallback(
        Uri.parse('https://user:pass@example.test/app/'),
      ),
      throwsArgumentError,
    );
    expect(
      () => InstanceAuthConfig.patchForWebCallback(
        Uri.parse('https://example.test/app/*'),
      ),
      throwsArgumentError,
    );
    expect(
      () => InstanceAuthConfig.patchForWebCallback(
        Uri.parse('https://example.test/app,other'),
      ),
      throwsArgumentError,
    );
    expect(
      () => InstanceAuthConfig.patchForWebCallback(
        Uri.parse('https://example.test/%2a'),
      ),
      throwsArgumentError,
    );
  });

  test(
    'builder and doctor use the same explicitly supplied web target',
    () async {
      final patch = InstanceAuthConfig.patchForWebCallback(
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
        contains('--site-url <app-url>'),
      );
    },
  );
}
