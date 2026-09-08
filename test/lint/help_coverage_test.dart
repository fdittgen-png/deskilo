// SPDX-License-Identifier: 0BSD
//
// #1016/#1019 — the migration from coarse topics to exact anchors,
// made measurable, and now finished. 152 help symbols shared 14 topics
// between them; screen by screen each moved onto its own object, and on
// 2026-09-08 the last one did.
//
// The ratchet has therefore become an invariant: EVERY help symbol
// names the object it sits beside. A new symbol without an `anchor:`
// fails this test, which is the point — the guide section is written in
// the same PR as the control it explains, or the control ships pointing
// at the nearest heading and nobody notices for a year.

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Help symbols still opening the nearest section instead of their own
/// object. It reached zero on 2026-09-08 and stays there: raising it
/// would be undoing #1019, not recording progress.
const _withoutAnchor = 0;

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
  test('every help symbol names the object it sits beside', () {
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
    expect(naked, isEmpty,
        reason: 'A help symbol without an anchor opens the nearest section, '
            'not its own object — ${naked.length} of $total do. Give it a '
            'HelpAnchor constant and write the guide section it names, in '
            'all five languages, in this PR. See '
            '.claude/skills/deskilo-documentation/SKILL.md.\n'
            '${naked.join('\n')}');
    expect(_withoutAnchor, 0,
        reason: 'the pin is an invariant now, not a ceiling to raise');
  });
}
