// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3623 — a place that takes a file through the picker also takes one
// dropped onto it (the desktop apps and the desktop web). The ratchet
// COUNTS the picker callers without a `FileDropZone`: the list below can
// only shrink, so a new file place cannot forget the drop, and a place
// that gains the zone must leave the list.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The picker callers that still take no drop, each with why. Do not add
/// to it: wrap the new place in a `FileDropZone` instead.
const _withoutDrop = <String, String>{
  'lib/features/workspace/presentation/screens/workspace_settings_restore.dart':
      'a destructive restore driven from a host mixin: needs its confirm '
      'flow lifted out of the picker first',
  'lib/features/task_recorder/presentation/screens/task_wizard_screen.dart':
      'a menu action, not a page: the file chooser sits in a popup',
  'lib/features/editor/presentation/level_canvas_flows.dart':
      'the plan image lands at the tapped cell: a drop has no cell yet',
  'lib/features/money/presentation/report_design_actions.dart':
      'a function flow that returns the parsed design: no widget to wrap',
  'lib/features/money/presentation/report_layout_design_actions.dart':
      'a function flow that returns the parsed layout: no widget to wrap',
  'lib/features/profile/presentation/widgets/account_settings_tiles.dart':
      'the photo is chosen from a bottom sheet beside "remove"',
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
