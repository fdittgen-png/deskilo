// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: a label lives in the part its NAME hashes to, and the generated
// file declares each part exactly once. Parts by position shifted on every
// added key, and merging two branches that each added labels duplicated the
// declarations (master stopped compiling).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/recorder_vocabulary.dart';

void main() {
  test('a key keeps its part, whatever else is added', () {
    expect(labelPart('tabEvents', 24), labelPart('tabEvents', 24));
    expect(labelPart('tabEvents', 24), inInclusiveRange(0, 23));
  });

  test('the generated labels declare every part exactly once', () {
    final text = File(
      'lib/features/task_recorder/presentation/ui_labels.g.dart',
    ).readAsStringSync();
    final declared = RegExp(
      r'^Map<String, _Getter> (_part\d+)\(\)',
      multiLine: true,
    ).allMatches(text).map((m) => m.group(1)!).toList();
    expect(
      declared.toSet().length,
      declared.length,
      reason: 'a duplicate part',
    );
    expect(declared, hasLength(24));
  });
}
