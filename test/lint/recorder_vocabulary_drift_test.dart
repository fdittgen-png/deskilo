// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3433 -- the task recorder's generated vocabulary is what its tool writes.
// `ui_vocabulary.g.dart` and `ui_labels.g.dart` come from
// `tool/recorder_vocabulary.dart`, which scans the hand-written `lib/` Dart
// and the English ARB; nothing compared the committed files with its output,
// so they went stale when code moved into packages (#3409, #3411) and no gate
// noticed. This recomputes both in memory and expects the committed text.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/recorder_vocabulary.dart';

void main() {
  test('the committed recorder vocabulary is what the tool produces', () {
    expect(
      File(vocabularyOutput).readAsStringSync(),
      vocabularyText(),
      reason:
          'the vocabulary drifted -- run `dart run tool/recorder_vocabulary.dart` '
          'and commit the result',
    );
  });

  test('the committed recorder labels are what the tool produces', () {
    expect(
      File(labelsOutput).readAsStringSync(),
      labelsText(),
      reason:
          'the labels drifted -- run `dart run tool/recorder_vocabulary.dart` '
          'and commit the result',
    );
  });
}
