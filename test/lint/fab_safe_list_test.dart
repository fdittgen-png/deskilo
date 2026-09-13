// SPDX-License-Identifier: 0BSD
//
// #1181 — a list with a floating action button over it must end above
// the button.
//
// The Messages list had no bottom padding at all, so the compose button
// covered the last conversation's date: the row was there, it just
// could not be read or reached. The first version of this test named
// the two screens the screenshot review happened to catch. Scanning
// found seven more with the identical defect, which is the whole
// argument for scanning.

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Screens that float a button over something that does NOT scroll
/// under it, with the reason each is exempt.
const _exempt = <String, String>{};

void main() {
  test('every list under a floating button ends above it', () {
    final offenders = <String>[];
    for (final file in handWrittenDartFiles('lib')) {
      final path = file.path;
      if (_exempt.containsKey(path)) continue;
      final src = file.readAsStringSync();
      if (!src.contains('floatingActionButton:')) continue;
      // Only the scrolling ones: a button over a fixed layout covers
      // nothing that could have been scrolled clear of it.
      final scrolls = src.contains('ListView') ||
          src.contains('CustomScrollView') ||
          src.contains('GridView');
      if (!scrolls) continue;
      if (!src.contains('kFabSafeBottom')) offenders.add(path);
    }
    expect(
      offenders,
      isEmpty,
      reason: 'these screens float a button over a scrolling list, and '
          'the list runs under it — its last row cannot be read or '
          'tapped. End the list with `kFabSafeBottom` of bottom '
          'padding, or add the file to _exempt with the reason it is '
          'not a list the button can cover.',
    );
  });
}
