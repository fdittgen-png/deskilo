// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 C4 — one candidate, bounded reuse, no cancelled release.
//
// The release train used to hand each leg a branch NAME, and the Android
// leg checked out `master` whatever was asked: a push during the train
// put two commits in one train under one label. Now the train resolves
// the ref ONCE to a full SHA, every leg takes that SHA as its
// `workflow_call` input, checks it out, refuses a HEAD that differs, and
// records SHA + flavor + defines + base href beside its artifact.
//
// Caches carry dependencies and toolchains keyed on the lockfile — never
// a verdict, never a run-specific key a fork could write into a release
// job. Concurrency cancels only a superseded pull request, inside its
// own workflow's group; a release or a deploy someone started queues.
//
// Read as YAML, not by regex: an input or a concurrency block is nested
// structure, and a regex that finds `required: true` somewhere is not a
// proof of WHICH input it belongs to.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _legs = {
  'android': 'play-internal.yml',
  'apple': 'ios-testflight.yml',
  'macos': 'macos-app.yml',
  'windows': 'windows-msi.yml',
  'web': 'web.yml',
};
const _sha = r'${{ steps.source.outputs.sha }}';
const _prOnly = r"${{ github.event_name == 'pull_request' }}";
const _identity = './.github/actions/source-identity';

/// Dependency and toolchain caches only — what a cache may carry. A new
/// path here is a deliberate decision, dated and reasoned.
const _cachePaths = {
  '~/.pub-cache', // packages, keyed on pubspec.lock (#1446 C3)
  '~/Library/Caches/CocoaPods', 'ios/Pods', // pods, keyed on Podfile.lock
  '~/.android/avd/*', '~/.android/adb*', // the emulator image (#93)
};

/// Keys that carry no lockfile hash: a toolchain image named by its own
/// configuration. 2026-09-25: the API 34 Pixel 6 AVD snapshot (#93).
const _toolchainKeys = {'avd-34-pixel6'};

YamlMap _yaml(String path) => loadYaml(File(path).readAsStringSync()) as YamlMap;
YamlMap _workflow(String file) => _yaml('.github/workflows/$file');
YamlMap _on(YamlMap w) => (w['on'] ?? w[true]) as YamlMap;
List<YamlMap> _steps(YamlMap job) => (job['steps'] as YamlList).cast<YamlMap>();
Iterable<File> _workflows() => Directory('.github/workflows')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.yml'));

void main() {
  test('the train resolves the ref once and hands the SHA to every leg',
      () {
    final train = _workflow('release-train.yml');
    expect((_on(train)['workflow_dispatch'] as YamlMap)['inputs'],
        contains('ref'),
        reason: 'the train takes the ref to ship; it resolves it itself');
    final jobs = train['jobs'] as YamlMap;
    final resolve = jobs['resolve'] as YamlMap?;
    expect(resolve?['outputs'], contains('sha'), reason: 'no resolve job');
    final run = _steps(resolve!).map((s) => s['run'] ?? '').join();
    expect(run, allOf(contains('gh api'), contains('/commits/'),
        contains(r'^[0-9a-f]{40}$')),
        reason: 'the resolution must be an API lookup checked to a full SHA');
    for (final entry in _legs.entries) {
      final leg = jobs[entry.key] as YamlMap;
      expect(leg['uses'], './.github/workflows/${entry.value}');
      expect(leg['needs'], contains('resolve'), reason: entry.key);
      final with_ = leg['with'] as YamlMap;
      expect(with_['source_sha'], r'${{ needs.resolve.outputs.sha }}',
          reason: '${entry.key} must receive the ONE resolved SHA');
      expect(with_, isNot(contains('ref')),
          reason: '${entry.key}: a ref beside the SHA is a second source');
    }
    expect((jobs['report'] as YamlMap)['needs'], contains('resolve'));
  });

  group('every leg takes the SHA, checks it out and proves it', () {
    for (final entry in _legs.entries) {
      test(entry.value, () {
        final w = _workflow(entry.value);
        final input = ((_on(w)['workflow_call'] as YamlMap)['inputs']
            as YamlMap)['source_sha'] as YamlMap?;
        expect(input?['required'], isTrue,
            reason: 'workflow_call must demand source_sha');
        expect(input?['type'], 'string');

        final job = (w['jobs'] as YamlMap).values.cast<YamlMap>().firstWhere(
            (j) => _steps(j).any((s) => s['uses'] == _identity),
            orElse: () => fail('${entry.value}: no job runs $_identity'));
        final steps = _steps(job);
        final source = steps.indexWhere((s) => s['id'] == 'source');
        expect(source, isNonNegative, reason: 'no `Pin the source` step');
        final pin = steps[source];
        expect((pin['env'] as YamlMap)['SOURCE_SHA'], r'${{ inputs.source_sha }}');
        expect(pin['run'], allOf(contains('gh api'), contains('/commits/'),
            contains(r'^[0-9a-f]{40}$'), contains('GITHUB_OUTPUT')));

        final checkouts = [
          for (var i = 0; i < steps.length; i++)
            if ('${steps[i]['uses']}'.startsWith('actions/checkout')) i
        ];
        expect(checkouts, isNotEmpty);
        for (final i in checkouts) {
          expect(i, greaterThan(source), reason: 'checkout before the pin');
          expect((steps[i]['with'] as YamlMap?)?['ref'], _sha,
              reason: 'the checkout must take the pinned SHA, not a ref');
        }
        final identity = steps.indexWhere((s) => s['uses'] == _identity);
        expect(identity, greaterThan(checkouts.last),
            reason: 'HEAD is verified after the checkout');
        final firstBuild = steps.indexWhere((s) =>
            '${s['run']}'.contains('flutter build') ||
            '${s['run']}'.contains('bundle exec fastlane'));
        expect(identity, lessThan(firstBuild),
            reason: 'verified BEFORE anything is built');
        final with_ = steps[identity]['with'] as YamlMap;
        expect(with_['sha'], _sha);
        expect(with_['leg'], entry.key);
        if (entry.key == 'web') {
          expect(with_['base_href'], r'${{ steps.base.outputs.base_href }}',
              reason: 'the web leg records the base href it builds with');
          expect(steps[firstBuild]['run'],
              contains(r'--base-href "${{ steps.base.outputs.base_href }}"'));
        }
        for (final s in steps) {
          if ('${s['uses']}'.startsWith('actions/upload-artifact')) {
            expect('${(s['with'] as YamlMap)['name']}',
                isNot(contains('github.sha')),
                reason: 'an artifact is named after the built SHA, not '
                    "the caller's dispatch-time one");
          }
        }
      });
    }
  });

  test('the identity action refuses a foreign HEAD and records four fields',
      () {
    final action = _yaml('.github/actions/source-identity/action.yml');
    expect((action['inputs'] as YamlMap).keys,
        containsAll(['sha', 'leg', 'flavor', 'defines', 'base_href']));
    final steps = _steps(action['runs'] as YamlMap);
    expect(steps.first['run'],
        allOf(contains('git rev-parse HEAD'), contains('exit 1')),
        reason: 'the first step is the refusal');
    for (final field in ['sha', 'flavor', 'defines', 'base_href']) {
      expect(steps[1]['run'], contains('echo "$field=\$'),
          reason: '$field is not written to the identity record');
    }
    final upload = steps.last['with'] as YamlMap;
    expect('${upload['name']}', startsWith('source-identity-'));
    expect(upload['overwrite'], isTrue,
        reason: 'a rerun replaces the record of the same candidate; it '
            'must not fail on the name or add a second record');
  });

  test('concurrency cancels only a superseded pull request, in its own '
      'workflow', () {
    for (final f in _workflows()) {
      final stem = f.uri.pathSegments.last.replaceAll('.yml', '');
      final w = _workflow(f.uri.pathSegments.last);
      final name = '${w['name']}';
      final block = w['concurrency'] as YamlMap?;
      final onPr = _on(w).containsKey('pull_request');
      if (onPr || name.startsWith('Release ·') || name.startsWith('Publish ·')) {
        expect(block, isNotNull,
            reason: '$stem: a pull-request or release workflow needs its '
                'own concurrency group');
      }
      if (block == null) continue;
      expect('${block['group']}', startsWith(stem),
          reason: '$stem: a group named after another workflow cancels '
              "that workflow's work");
      if (onPr) {
        expect('${block['group']}', contains(r'${{ github.ref }}'),
            reason: '$stem: a group without the ref cancels other PRs');
      }
      expect(block['cancel-in-progress'], anyOf(isFalse, _prOnly),
          reason: '$stem: only a superseded pull request may be cancelled; '
              'a bare `true` cancels a dispatch or a release someone '
              'started on purpose');
    }
    final train = _workflow('release-train.yml')['concurrency'] as YamlMap;
    expect(train['group'], 'release-train');
    expect(train['cancel-in-progress'], isFalse);
  });

  test('caches carry dependencies keyed on the lockfile, never a verdict '
      'or a run', () {
    var seen = 0;
    for (final f in _workflows()) {
      final stem = f.uri.pathSegments.last;
      final jobs = _workflow(stem)['jobs'] as YamlMap;
      for (final id in jobs.keys) {
        final job = jobs[id] as YamlMap;
        if (!job.containsKey('steps')) continue;
        for (final s in _steps(job)) {
          if (!'${s['uses']}'.startsWith('actions/cache')) continue;
          seen++;
          expect(id, isNot(anyOf('deploy', 'report')),
              reason: '$stem/$id: a publish job restores nothing');
          final with_ = s['with'] as YamlMap;
          final key = '${with_['key']}';
          expect(key, isNot(matches('head_ref|pull_request|run_id|run_number|run_attempt')),
              reason: '$stem/$id: a run- or PR-specific key is how a '
                  'verdict, or a fork, gets into a release job');
          if (!_toolchainKeys.contains(key)) {
            expect(key, matches(r"hashFiles\('[^']*lock'\)"),
                reason: '$stem/$id: key `$key` hashes no lockfile');
          }
          final paths = '${with_['path']}'.trim().split('\n').map((p) => p.trim());
          expect(paths, everyElement(isIn(_cachePaths)),
              reason: '$stem/$id: a cache path outside the dependency and '
                  'toolchain list — a test result, a build tree or a '
                  'report must be produced, never restored');
        }
      }
    }
    expect(seen, 3, reason: 'cache steps counted on 2026-09-25: pub, pods, '
        'avd — a new one is a deliberate decision, bump with a reason');
  });
}
