// SPDX-License-Identifier: 0BSD
//
// #835 — F-Droid ships OUR signed binary only while its rebuild of the
// pinned commit matches it byte for byte. Two invariants carry that, and
// both are split across two files that nothing else keeps in step: the
// absolute path the build runs at, and the signing key the recipe
// allows. Breaking either one goes unnoticed here and turns red on
// F-Droid's builder, days later, with the release already tagged.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Where GitHub Actions checks this repository out, and therefore the
/// only path at which F-Droid can reproduce a Dart AOT build of it.
const _runnerPath = '/home/runner/work/deskilo/deskilo';

const _abis = {
  'android-arm': 'armeabi-v7a',
  'android-arm64': 'arm64-v8a',
  'android-x64': 'x86_64',
};

void main() {
  final recipe = File('fdroid/de.deskilo.app.yml').readAsStringSync();
  final workflow =
      File('.github/workflows/fdroid-release.yml').readAsStringSync();

  test('the recipe builds where the publishing job builds — Dart AOT '
      'embeds its own path, so the two must agree exactly', () {
    // Once per build entry in prebuild AND in build: three entries, so
    // six relocations and six moves back.
    expect('export repo=$_runnerPath'.allMatches(recipe).length, 6,
        reason: 'every prebuild and build must relocate to $_runnerPath');
    expect('mv de.deskilo.app \$repo'.allMatches(recipe).length, 6);
    expect('mv \$repo de.deskilo.app'.allMatches(recipe).length, 6);

    // The job must NOT move anything: its default checkout already is
    // that path. A `cd` into a temporary directory would silently
    // publish a binary F-Droid can never match.
    expect(workflow, contains('ref: \${{ inputs.ref }}'));
    expect(workflow, isNot(contains('RUNNER_TEMP/build')),
        reason: 'build in the checkout, not in a temporary directory');
  });

  test('every build entry offers the binary for its own ABI', () {
    for (final entry in _abis.entries) {
      final abi = entry.value;
      expect(recipe, contains('app-$abi-release.apk'), reason: abi);
      expect(
        recipe,
        contains('/releases/download/v%v/deskilo-%v-$abi.apk'),
        reason: 'the $abi entry must point at the $abi asset',
      );
      expect(recipe, contains('--target-platform=${entry.key}'));
    }
    // The names the publishing job writes are the names it promises.
    expect(workflow, contains(r'deskilo-$NAME-$abi.apk'),
        reason: 'the asset name must carry the ABI the recipe asks for');
    expect(workflow,
        contains('for abi in ${_abis.values.join(' ')}'),
        reason: 'and cover every ABI, in the recipe\'s order');
  });

  test('the key the recipe allows is the key the job checks it signed with',
      () {
    final allowed = RegExp(r'^AllowedAPKSigningKeys: ([0-9a-f]{64})$',
            multiLine: true)
        .firstMatch(recipe)
        ?.group(1);
    expect(allowed, isNotNull,
        reason: 'a verified build must pin the certificate it accepts');
    expect(workflow, contains('default: $allowed'),
        reason: 'the publishing job would sign with a key F-Droid refuses');
  });

  test('each ABI is built from a clean build directory, as F-Droid does '
      'from a fresh checkout', () {
    expect(workflow, contains('rm -rf build'));
    // And the job proves it can repeat itself before it publishes.
    expect(workflow, contains('NOT REPRODUCIBLE'));
  });
}
