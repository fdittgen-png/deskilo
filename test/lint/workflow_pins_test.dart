// SPDX-License-Identifier: 0BSD
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
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every Flutter setup reads the version from its workflow env', () {
    final workflows = Directory('.github/workflows')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yml'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
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
}
