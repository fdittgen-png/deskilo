// SPDX-License-Identifier: 0BSD
//
// Design-token lint: inline `BorderRadius.circular(n)` is banned in feature
// code — use the AppRadius tokens (spec §14, DESIGN_SYSTEM.md).

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _exempt = ['lib/core/theme/app_radius.dart'];

void main() {
  test('no inline BorderRadius.circular outside AppRadius', () {
    final violations = <String>[];

    final files = handWrittenDartFiles('lib')
        .where((f) => !_exempt.contains(f.path));
    violations.addAll(
      scanLines(files, (line) => line.contains('BorderRadius.circular(')),
    );

    expect(
      violations,
      isEmpty,
      reason: 'Inline BorderRadius in: $violations — use AppRadius tokens.',
    );
  });
}
