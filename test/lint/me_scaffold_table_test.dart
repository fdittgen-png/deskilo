// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step 0 -- a screen of Me is walked by the experience guards or it does
// not exist: every file under lib/features/me/presentation that builds a
// Scaffold is a source of a row in test/ux/me_screens.dart (or one of the
// shell files it names).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../ux/me_screens.dart';
import 'lint_sources.dart';

void main() {
  test('every Scaffold of Me is in the experience guards table', () {
    final listed = {
      for (final s in meScreens) ...s.sources,
      ...meShellScaffolds,
    };
    final missing = [
      for (final f in handWrittenDartFiles('lib/features/me/presentation'))
        if (RegExp(r'\bScaffold\(').hasMatch(f.readAsStringSync()) &&
            !listed.contains(f.uri.pathSegments.last))
          f.path,
    ];
    expect(
      missing,
      isEmpty,
      reason: 'add the screen to test/ux/me_screens.dart (#3545):\n'
          '${missing.join('\n')}',
    );
    for (final name in listed) {
      expect(
        File('lib/features/me/presentation/$name').existsSync(),
        isTrue,
        reason: '$name is in the table but does not exist',
      );
    }
  });
}
