// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2142 — the task recorder names a tapped control by its string key; a
// control without one is recorded as a gap ("an unnamed control"). This
// counts the interactive callbacks in lib/**/presentation/ whose widget
// call names no `key:`, and the count may only fall: a new screen keys
// its controls, an old one is keyed when it is touched.
//
// `dart run tool/recorder_vocabulary.dart --report` prints the count per
// feature, and regenerates the vocabulary the recorder names keys from.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/recorder_vocabulary.dart' show unkeyedByFeature;

/// The ceiling. Lower it when a change keys controls; never raise it.
const int _unkeyedCeiling = 430;

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
