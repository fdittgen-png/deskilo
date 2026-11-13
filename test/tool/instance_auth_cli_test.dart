// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3259 — Every CLI setup and doctor path uses the explicit deployment
// target, while omitting the option retains the existing legacy default.
import 'package:deskilo/core/instance/instance_builder.dart';
import 'package:deskilo/core/instance/instance_bundle.dart';
import 'package:deskilo/core/instance/instance_doctor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/instance.dart' as cli;
import '../helpers/fake_supabase_management.dart';

void main() {
  const bundle = InstanceBundle(schema: [(name: '0001_initial.sql', sql: 'select 1;')], functions: []);
  const url = 'https://www.deskilo.org/app/';
  final expected = InstanceAuthConfig.patchForWebBase(Uri.parse(url));
  final options = ['--token', 'dummy', '--site-url', '$url?temporary=x#route'];

  for (final command in ['create', 'install', 'auth']) {
    test('$command sends the explicit target to management', () async {
      final api = FakeSupabaseManagement();
      final args = [command, ...options, if (command == 'create') ...['--org', 'org-1', '--name', 'test'] else ...['--ref', 'ref1xxxxxxxxxxxxxxxx']];
      expect(await cli.run(args, apiOverride: api, bundleLoader: () => bundle), 0);
      expect(api.authPatches['ref1xxxxxxxxxxxxxxxx']!.single, expected);
    });
  }

  test('doctor checks the same target and offers an exact safe repair command', () async {
    final api = FakeSupabaseManagement()..authConfigValue = InstanceAuthConfig.patch;
    List<DoctorFinding>? findings;
    await cli.run(['doctor', ...options, '--ref', 'ref1xxxxxxxxxxxxxxxx'], apiOverride: api,
        bundleLoader: () => bundle, onDoctorFindings: (value) => findings = value);
    final site = findings!.firstWhere((f) => f.title == 'Site URL is not the app');
    expect(site.detail, contains("--site-url 'https://www.deskilo.org/app/'"));
    api.authConfigValue = expected;
    await cli.run(['doctor', ...options, '--ref', 'ref1xxxxxxxxxxxxxxxx'], apiOverride: api,
        bundleLoader: () => bundle, onDoctorFindings: (value) => findings = value);
    expect(findings!.firstWhere((f) => f.title == 'Site URL').level, DoctorLevel.ok);
  });

  test('legacy auth default is retained', () async {
    final api = FakeSupabaseManagement();
    expect(await cli.run(['auth', '--token', 'dummy', '--ref', 'ref1xxxxxxxxxxxxxxxx'], apiOverride: api), 0);
    expect(api.authPatches['ref1xxxxxxxxxxxxxxxx']!.single, InstanceAuthConfig.patch);
  });
}
