// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Workflow credentials stay outside pull requests and public reports, and
// temporary signing material is removed after success or failure.
// test-inventory: structure is the invariant — these YAML guards control runner authority.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

YamlMap _workflow(String name) =>
    loadYaml(File('.github/workflows/$name.yml').readAsStringSync()) as YamlMap;

YamlMap _mapAt(YamlMap map, String key) => map[key] as YamlMap;

YamlMap _job(String workflow, String job) =>
    _mapAt(_mapAt(_workflow(workflow), 'jobs'), job);

List<YamlMap> _steps(String workflow, String job) =>
    (_job(workflow, job)['steps'] as YamlList).cast<YamlMap>();

YamlMap _step(String workflow, String job, String name) =>
    _steps(workflow, job).singleWhere((step) => step['name'] == name);

void main() {
  test('desktop builds keep release writes in a tag-only artifact job', () {
    for (final entry in {'windows-msi': 'msi', 'macos-app': 'dmg'}.entries) {
      final workflow = _workflow(entry.key);
      expect(workflow['permissions'], {'contents': 'read'});
      final jobs = workflow['jobs'] as YamlMap;
      final build = jobs[entry.value] as YamlMap;
      expect(build['permissions'], isNull);
      final attach = jobs['attach'] as YamlMap;
      expect(attach['needs'], entry.value);
      expect(attach['if'], "startsWith(github.ref, 'refs/tags/v')");
      expect(attach['permissions'], {'contents': 'write'});
      expect(
        ((attach['steps'] as YamlList).first as YamlMap)['uses'],
        'actions/download-artifact@v4',
      );
    }
  });

  test('Windows signing never loads certificates on a pull request', () {
    final signing = _steps('windows-msi', 'msi').where(
      (step) =>
          step['env'] is YamlMap &&
          (step['env'] as YamlMap).containsKey('PFX_B64'),
    );
    expect(signing, hasLength(2));
    for (final step in signing) {
      expect(step['if'], "github.event_name != 'pull_request'");
    }
    final cleanup = _step(
      'windows-msi',
      'msi',
      'Clean up the signing certificate',
    );
    expect(cleanup['if'], 'always()');
    expect(
      cleanup['run'],
      allOf(contains('Remove-Item'), contains('codesign.pfx')),
    );
  });

  test('the Android upload keystore is removed on failure too', () {
    final cleanup = _step(
      'play-internal',
      'build-and-upload',
      'Clean up keystore',
    );
    expect(cleanup['if'], 'always()');
    expect(
      cleanup['run'],
      allOf(contains('upload-keystore.p12'), contains('key.properties')),
    );
  });

  test('dictionary writes are confined to its refresh job', () {
    final workflow = _workflow('dictionary-refresh');
    expect(workflow['permissions'], {'contents': 'read'});
    final permissions = _mapAt(
      _job('dictionary-refresh', 'refresh'),
      'permissions',
    );
    expect(permissions['contents'], 'write');
    expect(permissions['pull-requests'], 'write');
    expect(permissions['actions'], 'write');
    expect(permissions['packages'], 'read');
  });

  test('the public doctor report excludes stderr', () {
    final run =
        _step('instance-doctor', 'doctor', 'Examine the project')['run']
            as String;
    expect(run, contains('--public > doctor.txt'));
    expect(run, isNot(contains('2>&1')));
  });

  test('the Edge deployment CLI is the replay\'s: one pinned, cached install', () {
    final setup = _step(
      'edge-functions',
      'functions',
      'Install the pinned deployment CLI',
    );
    expect(setup['if'], "steps.gate.outputs.ready == 'true'");
    // #3473 -- both go through the one composite (cache first, checksum
    // verified), never a download of their own
    expect(setup['uses'], './.github/actions/supabase-cli');
    final replay = _steps('quality', 'database').singleWhere(
      (step) => step['uses'] == './.github/actions/supabase-cli',
    );
    expect(replay['if'], "env.DB_REQUIRED == 'true'");
    for (final step in [..._steps('quality', 'database')]) {
      expect(
        (step['uses'] as String? ?? '').startsWith('supabase/setup-cli@'),
        isFalse,
      );
    }
    final deploy =
        _step('edge-functions', 'functions', 'Deploy')['run'] as String;
    expect(deploy, isNot(contains('releases/latest')));
  });

  test('the toolchain installs are pinned, cached and checksum-verified', () {
    final cli = File('scripts/install_supabase_cli.sh').readAsStringSync();
    expect(cli, contains('version=2.118.0'));
    expect(cli, matches(RegExp(r'archive_sha=[0-9a-f]{64}')));
    expect(cli, matches(RegExp(r'binary_sha=[0-9a-f]{64}')));
    final cliAction = File('.github/actions/supabase-cli/action.yml')
        .readAsStringSync();
    expect(cliAction, contains('actions/cache@v4'));
    expect(cliAction, contains('toolchain-supabase-cli-2.118.0-'));
    final denoAction =
        File('.github/actions/deno/action.yml').readAsStringSync();
    expect(denoAction, contains('actions/cache@v4'));
    expect(denoAction, contains('deno-version: 2.9.8'));
    expect(denoAction, isNot(contains('v2.x')));
    expect(denoAction, contains('verify_cached_deno.sh clear'));
    expect(denoAction, contains('verify_cached_deno.sh check'));
    expect(
      File('scripts/verify_cached_deno.sh').readAsStringSync(),
      matches(RegExp(r'expected=[0-9a-f]{64}')),
    );
    final gitleaks = File('scripts/install_gitleaks.sh').readAsStringSync();
    expect(gitleaks, contains('checksum mismatch'));
  });

  test(
    'the required gate scans the complete PR range before package setup',
    () {
      final steps = _steps('quality', 'static');
      final checkout = steps.first;
      expect(_mapAt(checkout, 'with')['fetch-depth'], 0);
      final scan = steps.singleWhere(
        (step) =>
            step['name'] == 'Scan the current tree and every commit in the PR',
      );
      expect(
        _mapAt(scan, 'env')['SCAN_BASE'],
        r'${{ github.event.pull_request.base.sha }}',
      );
      expect(
        _mapAt(scan, 'env')['SCAN_HEAD'],
        r'${{ github.event.pull_request.head.sha }}',
      );
      expect(
        scan['run'],
        allOf(
          contains('scripts/secret_scan_check.sh'),
          contains('scripts/secret_scan.sh'),
        ),
      );
      final setup = steps.indexWhere(
        (step) => (step['uses'] as String? ?? '').startsWith(
          'subosito/flutter-action@',
        ),
      );
      expect(steps.indexOf(scan), lessThan(setup));
    },
  );

  test('action update automation has a bounded PR queue', () {
    final config =
        loadYaml(File('.github/dependabot.yml').readAsStringSync()) as YamlMap;
    final update = (config['updates'] as YamlList).single as YamlMap;
    expect(update['package-ecosystem'], 'github-actions');
    expect(update['open-pull-requests-limit'], 1);
    expect(update['groups'], contains('actions'));
  });

  test('action update automation never proposes a major version', () {
    final config =
        loadYaml(File('.github/dependabot.yml').readAsStringSync()) as YamlMap;
    final update = (config['updates'] as YamlList).single as YamlMap;
    final ignore = (update['ignore'] as YamlList).single as YamlMap;
    expect(ignore['dependency-name'], '*');
    expect(ignore['update-types'], ['version-update:semver-major']);
  });
}
