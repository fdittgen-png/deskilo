// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2142 — the task recorder names a tapped control by its string key; a
// control without one is recorded as a gap ("an unnamed control"). This
// counts the interactive callbacks in lib/**/presentation/ whose widget
// call names no `key:` (or a `fooKey:` it hands to its control).
// #2313 — every control was keyed: the ceiling is 0, so a new control
// arrives with its key. A callback that is not a control (a link style,
// a canvas's semantics, a data callback) says so with
// `// recorder-key-exempt: <why>` on its line or the one above.
//
// `dart run tool/recorder_vocabulary.dart --report` prints the count per
// feature, and regenerates the vocabulary the recorder names keys from.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/recorder_vocabulary.dart' show unkeyedByFeature;

/// The ceiling: none. Never raise it.
const int _unkeyedCeiling = 0;

void main() {
  test('controls without a key only ever decrease (#2142)', () {
    final byFeature = unkeyedByFeature();
    final total = byFeature.values.fold(0, (a, b) => a + b);
    expect(
      total,
      lessThanOrEqualTo(_unkeyedCeiling),
      reason:
          'a new interactive control without a ValueKey<String> is a gap in '
          'every task recording: give it a key (by feature: $byFeature)',
    );
  });
}
