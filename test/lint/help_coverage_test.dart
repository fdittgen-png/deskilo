// SPDX-License-Identifier: 0BSD
//
// #1016 — the migration from coarse topics to exact anchors, made
// measurable. 152 help symbols shared 14 topics; each documented screen
// moves some of them onto their own object. This number may only fall.

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Help symbols that still open the nearest section instead of their own
/// object. Lower it in the PR that documents a screen; never raise it.
///
/// 2026-09-08 #1016: 152 at the start, VAT's four migrated first.
const _withoutAnchor = 115;

final _call = RegExp(r'\bHelpDot(?:Title)?\(');

/// The call's own parentheses, so a nested `HelpDot` inside another
/// widget's argument list is not mistaken for this one's.
String _callSource(String source, int start) {
  var depth = 0;
  for (var i = start; i < source.length; i++) {
    final c = source[i];
    if (c == '(') depth++;
    if (c == ')') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  return source.substring(start);
}

void main() {
  test('every help symbol is moving towards an anchor, never away', () {
    final naked = <String>[];
    var total = 0;
    for (final file in handWrittenDartFiles('lib')) {
      // The widgets themselves declare the parameter; they are not sites.
      if (file.path.contains('lib/core/help/')) continue;
      final source = file.readAsStringSync();
      for (final match in _call.allMatches(source)) {
        total++;
        final call = _callSource(source, match.end - 1);
        if (!call.contains('anchor:')) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
          naked.add('${file.path}:$line');
        }
      }
    }
    expect(total, greaterThan(100), reason: 'the symbols did not disappear');
    expect(naked.length, lessThanOrEqualTo(_withoutAnchor),
        reason: 'A help symbol without an anchor opens the nearest section, '
            'not its own object. ${naked.length} of $total are still coarse; '
            'the pinned ceiling is $_withoutAnchor and may only go down.');
    // And when it falls, say so, so the pin follows in the same PR.
    expect(naked.length, greaterThanOrEqualTo(_withoutAnchor - 8),
        reason: 'good — ${naked.length} left of $total. Lower _withoutAnchor '
            'to that number in this PR.');
  });
}
