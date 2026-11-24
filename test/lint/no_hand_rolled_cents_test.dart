// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1140 — after #1077 every amount an editor reads or shows goes through
// `parseMinorInput` / `centsToMajor`, which know the currency's minor
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
        reason: 'use parseMinorInput / centsToMajor (lib/core/format/cents.dart):'
            '\n${hits.join('\n')}');
  });

  // #4424 -- nor, in any screen, a value held in minor units divided by a
  // literal 100 to show or prefill it: a yen or a dinar has its own digits.
  test('no screen divides a minor amount by a literal 100', () {
    final hits = scanLines(
      handWrittenDartFiles('lib/features').where((f) => f.path.contains('/presentation/')),
      (line) => RegExp(r'\w*Minor!?\s*/\s*100\b').hasMatch(line),
    );
    expect(hits, isEmpty,
        reason: 'use amountInputText / AppFormat.money (lib/core/format):\n${hits.join('\n')}');
    expect(RegExp(r'\w*Minor!?\s*/\s*100\b').hasMatch(r"'${plan!.highValueMinor! / 100}'"), isTrue);
  });
}
