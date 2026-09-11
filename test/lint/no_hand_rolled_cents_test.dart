// SPDX-License-Identifier: 0BSD
//
// #1140 — after #1077 every amount an editor reads or shows goes through
// `parseCentsInput` / `centsToMajor`, which know the currency's minor
// digits. A hand-rolled `* 100` stores ¥1000 as ¥100,000.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  test('no money editor multiplies or divides by a literal 100', () {
    final hits = scanLines(
      handWrittenDartFiles('lib/features/money/presentation'),
      (line) =>
          line.contains('* 100).round()') ||
          RegExp(r'[A-Za-z_!)\]] / 100\)').hasMatch(line),
    ).where((h) => !h.contains('zoom') && !h.contains('.w!.value')).toList();
    expect(hits, isEmpty,
        reason: 'use parseCentsInput / centsToMajor (lib/core/format/cents.dart):'
            '\n${hits.join('\n')}');
  });
}
