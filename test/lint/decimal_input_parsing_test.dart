// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3487 — a number a member types is read by `parseDecimalInput` /
// `parseMinorInput` (lib/core/format) and nowhere else: a screen that calls
// `double.tryParse` itself reads `0,5` from a German keyboard as nothing.
// Recorded at 17 presentation sites on ad22e6f68; pinned at 0.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  test('no screen or application file parses a typed decimal by hand', () {
    final files = handWrittenDartFiles('lib').where(
      (f) => RegExp(r'^lib/features/[^/]+/(presentation|application)/')
          .hasMatch(f.path),
    );
    final hits = scanLines(
      files,
      (line) => RegExp(r'\b(double|num)\.(try)?[pP]arse\(').hasMatch(line),
    );
    expect(
      hits,
      isEmpty,
      reason:
          'read typed numbers with parseDecimalInput or parseMinorInput '
          '(lib/core/format):\n${hits.join('\n')}',
    );
  });

  test('the old amount parser is gone', () {
    final hits = scanLines(
      handWrittenDartFiles('lib'),
      (line) => line.contains('parseCentsInput'),
    );
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
