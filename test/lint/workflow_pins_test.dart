// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #706 — every workflow that builds the app builds it with the SAME
// Flutter, and says so in one place.
//
// Seven workflows declared `FLUTTER_VERSION` at the top and read it at
// the use site. The eighth — `ios-testflight.yml`, the RELEASE leg for
// iOS — spelled the literal inline instead. A version bump was
// therefore a seven-file edit that looked complete and left the one
// workflow nobody re-reads on the old toolchain, shipping a store build
// from a different Flutter than the one every test ran against.
//
// The failure mode is silent by construction, which is what makes it
// worth a test rather than a comment: nothing goes red, the build just
// comes from somewhere else.

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  test('every Flutter setup reads the version from its workflow env', () {
    final workflows = filesWithExtension('.github/workflows', '.yml');
    expect(workflows, isNotEmpty, reason: 'no workflows found — wrong cwd?');

    final versions = <String, String>{};
    for (final file in workflows) {
      final source = file.readAsStringSync();
      final uses = RegExp(r'flutter-version:\s*(.+)').allMatches(source);
      for (final use in uses) {
        final value = use.group(1)!.trim();
        // #809 — two ways to say it, and both are indirection. The
        // workflow's own `env:` block is the historical one; reading
        // .flutter-version is the stronger one, because that file is
        // also what fdroiddata's recipe cats. An INLINE version is what
        // this forbids either way: it is the pin a version bump misses.
        expect(
          value,
          anyOf(
            r'${{ env.FLUTTER_VERSION }}',
            r'${{ steps.flutter_pin.outputs.version }}',
          ),
          reason: '${file.path} pins Flutter inline. Read it from the '
              "workflow's `env:` block or from .flutter-version via a "
              '`flutter_pin` step — an inline pin is the one a version '
              'bump misses.',
        );
      }
      final declared =
          RegExp(r'FLUTTER_VERSION:\s*"([^"]+)"').firstMatch(source);
      if (declared != null) versions[file.path] = declared.group(1)!;
    }

    // And they all agree: two versions across the workflows means the
    // thing that ships is not the thing that was tested.
    expect(
      versions.values.toSet(),
      hasLength(1),
      reason: 'workflows disagree on the Flutter version: $versions',
    );
  });

  test('every Dart setup names an exact SDK version, never `stable`', () {
    // #3473 -- the jobs that classify the change install Dart on every run
    // and feed a gate line of the required report: a floating channel is a
    // different toolchain on a different day.
    var seen = 0;
    for (final file in filesWithExtension('.github/workflows', '.yml')) {
      final source = file.readAsStringSync();
      final steps = RegExp(
        r'uses:\s*dart-lang/setup-dart@[^\n]*\n\s*with:\s*\n\s*sdk:\s*([^\s#]+)',
      ).allMatches(source);
      for (final step in steps) {
        seen++;
        expect(
          step.group(1)!.replaceAll('"', ''),
          matches(RegExp(r'^\d+\.\d+\.\d+$')),
          reason: '${file.path}: a Dart setup must pin x.y.z, the Dart of '
              'the pinned Flutter',
        );
      }
    }
    expect(seen, greaterThanOrEqualTo(2), reason: 'no Dart setup found?');
  });
}
