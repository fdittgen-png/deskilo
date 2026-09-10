// SPDX-License-Identifier: 0BSD
//
// #1055 — an icon button says what it does.
//
// An IconButton with no `tooltip:` is a glyph and nothing else: a screen
// reader announces "button", and on desktop and web there is no hover
// label either. 25 of the app's 106 were like that — the chevrons that
// step a month, the tick that closes an inline editor, the bin on a
// document row.
//
// The suite already gates database grants, file length, hard-coded
// strings, wall-clock reads, contrast and touch targets. This is the same
// idea pointed at the part a person actually touches.
//
// Baseline zero, deliberately. The sweep finished, so there is no debt to
// carry and no allow-list to argue with: the next unlabelled button is a
// new one, and it fails here rather than shipping mute.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The body of every `IconButton(...)` in [source], paren-balanced so a
/// nested widget's own arguments cannot end the match early.
Iterable<(int, String)> iconButtonBodies(String source) sync* {
  for (final match in RegExp(r'IconButton\(').allMatches(source)) {
    var i = match.end - 1;
    var depth = 0;
    while (i < source.length) {
      if (source[i] == '(') {
        depth++;
      } else if (source[i] == ')') {
        depth--;
        if (depth == 0) break;
      }
      i++;
    }
    final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
    yield (line, source.substring(match.end, i));
  }
}

void main() {
  test('every IconButton names the action it performs', () {
    final mute = <String>[];
    for (final file in handWrittenDartFiles('lib')) {
      for (final (line, body) in iconButtonBodies(file.readAsStringSync())) {
        if (body.contains('tooltip:')) continue;
        final icon = RegExp(r'Icons\.([A-Za-z_0-9]+)').firstMatch(body);
        mute.add('${file.path}:$line  Icons.${icon?.group(1) ?? '?'}');
      }
    }
    expect(
      mute,
      isEmpty,
      reason: 'These icon buttons announce as "button" and nothing more:\n'
          '${mute.join('\n')}\n\n'
          'Give each a tooltip. Material already translates the generic '
          'ones — MaterialLocalizations.of(context).closeButtonTooltip, '
          '.deleteButtonTooltip, .previousMonthTooltip, .nextMonthTooltip '
          '— so a new ARB key is only for an action Material has no word '
          'for.',
    );
  });

  test('the matcher is not fooled by a nested widget', () {
    const source = '''
IconButton(
  icon: Icon(Icons.close),
  onPressed: () => Navigator.of(context).pop(),
)
''';
    final bodies = iconButtonBodies(source).toList();
    expect(bodies, hasLength(1));
    expect(bodies.single.$2, contains('Navigator.of(context).pop()'),
        reason: 'the inner parens must not close the IconButton early — '
            'that is how a mute button hides behind a callback');
    expect(bodies.single.$2, isNot(contains('tooltip:')));
  });

  test('a tooltip anywhere in the body counts, however it is written', () {
    const source = '''
IconButton(
  icon: const Icon(Icons.add),
  onPressed: onAdd,
  tooltip: l10n?.a11yIncrease ?? 'Increase',
)
''';
    expect(iconButtonBodies(source).single.$2, contains('tooltip:'));
  });
}
