// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3623 — a place that takes a file through the picker also takes one
// dropped onto it (the desktop apps and the desktop web). The ratchet
// COUNTS the picker callers without a `FileDropZone`: the list below can
// only shrink, so a new file place cannot forget the drop, and a place
// that gains the zone must leave the list.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The picker callers that take no drop BY DESIGN, each with why. Do not
/// add to it: wrap the new place in a `FileDropZone` instead.
const _withoutDrop = <String, String>{
  'lib/features/editor/presentation/level_canvas_flows.dart':
      'the plan image lands at the tapped cell: a drop carries no cell, and '
      'placing it at a guessed one would skip the step that decides where',
};

void main() {
  test('every picker caller takes a dropped file too, or is on the shrinking '
      'list', () {
    final without = <String>{};
    for (final file in handWrittenDartFiles('lib')) {
      final path = file.path.replaceAll(r'\', '/');
      if (path == 'lib/core/files/file_picker.dart') continue;
      final text = file.readAsStringSync();
      if (!text.contains('filePickerProvider')) continue;
      if (!text.contains('FileDropZone(')) without.add(path);
    }
    expect(
      without.difference(_withoutDrop.keys.toSet()),
      isEmpty,
      reason: 'a place that takes a picked file must also be wrapped in a '
          'FileDropZone (lib/core/files/file_drop.dart)',
    );
    expect(
      _withoutDrop.keys.toSet().difference(without),
      isEmpty,
      reason: 'these places now take a drop: remove them from the list',
    );
  });
}
