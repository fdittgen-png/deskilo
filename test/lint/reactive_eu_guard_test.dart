// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3403/#3441 -- `workspaceIsEu(` reads the workspace's tax reference ONCE and
// answers false while the context is not ready. Inside a `build` that value
// would stay false after the context arrives (the e-invoice action hidden
// until the sheet reopens), so a `build` asks `watchWorkspaceIsEu(`.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  test('no build method reads workspaceIsEu once', () {
    final inBuild = <String>[];
    final member = RegExp(r'^  [A-Za-z@].*[({]\s*$|^  [A-Za-z].*\(.*');
    for (final f in handWrittenDartFiles('lib')) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!RegExp(r'(?<!watch)workspaceIsEu\(', caseSensitive: false)
                .hasMatch(lines[i]) ||
            lines[i].trimLeft().startsWith('///') ||
            lines[i].contains(' show ')) {
          continue;
        }
        var j = i;
        while (j > 0 && !member.hasMatch(lines[j])) {
          j--;
        }
        if (lines[j].contains('Widget build(')) inBuild.add('${f.path}:${i + 1}');
      }
    }
    expect(
      inBuild,
      isEmpty,
      reason: 'a build watches: use watchWorkspaceIsEu(ref, country)',
    );
  });
}
