// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 C4 — one candidate: a leg builds the SHA it was given, or nothing.
//
// The release train handed each leg a branch NAME, and the Android leg
// checked out `master` whatever was asked: a push during the train put
// two commits in one train under one label. Now every leg takes the
// candidate as a full SHA (its `workflow_call` input, or its own dispatch
// ref resolved once, before the checkout), checks THAT out, refuses a
// HEAD that differs, and records SHA + flavor + defines + base href.
//
// Read as YAML, not by regex: an input is nested structure, and a regex
// that finds `required: true` somewhere does not say WHICH input's.
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
const _identity = './.github/actions/source-identity';

YamlMap _yaml(String path) => loadYaml(File(path).readAsStringSync()) as YamlMap;
YamlMap _workflow(String file) => _yaml('.github/workflows/$file');
YamlMap _on(YamlMap w) => (w['on'] ?? w[true]) as YamlMap;
List<YamlMap> _steps(YamlMap job) => (job['steps'] as YamlList).cast<YamlMap>();

void main() {
  group('every leg takes the SHA, checks it out and proves it', () {
    for (final entry in _legs.entries) {
      test(entry.value, () {
        final w = _workflow(entry.value);
        final input = ((_on(w)['workflow_call'] as YamlMap)['inputs']
            as YamlMap)['source_sha'] as YamlMap?;
        expect(input, isNotNull, reason: 'workflow_call takes no SHA');
        expect(input!['type'], 'string');

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
}
