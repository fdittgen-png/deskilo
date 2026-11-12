// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3611 — nothing is reachable by a gesture alone.
//
// A swipe (`Dismissible`) or a long press (`onLongPress…:`) is invisible
// and has no mouse or keyboard equivalent. Every one of them in `lib/`
// therefore names, in a `// parity: <key>` comment on one of the lines
// just above it, the visible control that starts the same action: the
// key prefix of a `RowMenu` (whose ⋯, right click, long press and
// context-menu key open one menu) or of a visible button. The key must
// be a string in the same file, so the comment cannot point at nothing.
//
// A `Semantics(onLongPress: …)` is an accessibility action, not a
// gesture, and is not counted.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// How many lines above a gesture its `// parity:` comment may sit.
const _markerReach = 4;

/// Gestures whose action has no place on a desk with a mouse, with the
/// reason. The list starts and stays as short as it can.
const _exempt = <String, String>{
  'lib/app/shell/shell_center_button.dart':
      "the phone bar's centre button hides and shows the bottom bar; "
      'the desk has no bottom bar to hide (its navigation is the '
      'column beside the page)',
};

final _gesture = RegExp(r'\bDismissible\(|\bonLongPress\w*:');
final _marker = RegExp(r'//\s*parity:\s*(\S+)');

/// The constructor or call whose argument list holds [offset].
String? _enclosingCall(String src, int offset) {
  var depth = 0;
  for (var i = offset - 1; i >= 0; i--) {
    final c = src[i];
    if (c == ')') depth++;
    if (c == '(') {
      if (depth == 0) {
        final name = RegExp(r'([A-Za-z_][\w.<>]*)\s*$')
            .firstMatch(src.substring(0, i));
        return name?.group(1);
      }
      depth--;
    }
  }
  return null;
}

/// The gestures of [src] with no visible twin, as `path:line`.
List<String> parityOffenders(String path, String src) {
  final lines = src.split('\n');
  final offenders = <String>[];
  var offset = 0;
  final starts = <int>[];
  for (final line in lines) {
    starts.add(offset);
    offset += line.length + 1;
  }
  for (final match in _gesture.allMatches(src)) {
    final lineIndex = starts.lastIndexWhere((s) => s <= match.start);
    final line = lines[lineIndex];
    if (line.trimLeft().startsWith('//')) continue;
    final call = _enclosingCall(src, match.start);
    if (call == 'Semantics' && !match.group(0)!.startsWith('Dismissible')) {
      continue;
    }
    String? token;
    for (var i = lineIndex; i >= 0 && i >= lineIndex - _markerReach; i--) {
      token = _marker.firstMatch(lines[i])?.group(1);
      if (token != null) break;
    }
    final named =
        token != null &&
        lines.any(
          (l) => !l.trimLeft().startsWith('//') && l.contains("'$token"),
        );
    if (!named) offenders.add('$path:${lineIndex + 1}');
  }
  return offenders;
}

void main() {
  test('the exemptions only fall, and each still holds its gesture', () {
    // One today (the centre button's long press); it goes with the visible
    // control that the second part of #3611 gives it. Never raise this.
    expect(_exempt.length, lessThanOrEqualTo(1));
    for (final path in _exempt.keys) {
      expect(
        _gesture.hasMatch(File(path).readAsStringSync()),
        isTrue,
        reason: '$path no longer holds a swipe or a long press: '
            'remove its exemption',
      );
    }
  });

  test('every swipe and long press in lib/ has a visible twin', () {
    final offenders = <String>[];
    for (final file in handWrittenDartFiles('lib')) {
      final path = file.path;
      if (_exempt.containsKey(path)) continue;
      offenders.addAll(parityOffenders(path, file.readAsStringSync()));
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'a swipe or a long press is the only way to these actions, '
          'so a mouse or a keyboard cannot reach them. Declare the '
          'actions once in a `RowMenu` (lib/core/ui/kit/row_menu.dart) '
          'and let the gesture call the same RowAction, or give the '
          'action a visible button; then name its key prefix in a '
          '`// parity: <key>` comment just above the gesture.',
    );
  });

  test('the lint bites on a planted swipe-only action', () {
    const swipeOnly = '''
Widget build(BuildContext context) {
  return Dismissible(
    key: ValueKey('row-1'),
    confirmDismiss: (_) => delete(),
    child: tile,
  );
}
''';
    expect(parityOffenders('planted.dart', swipeOnly), ['planted.dart:2']);

    const longPressOnly = '''
final row = ListTile(
  onTap: open,
  onLongPress: marks,
);
''';
    expect(parityOffenders('planted.dart', longPressOnly), ['planted.dart:3']);
  });

  test('a marker naming a key that is not in the file does not count', () {
    const dangling = '''
// parity: row-menu-
final row = GestureDetector(onLongPress: delete, child: tile);
''';
    expect(parityOffenders('planted.dart', dangling), ['planted.dart:2']);
  });

  test('a marker naming a visible control passes; Semantics is no gesture', () {
    const paired = '''
final more = IconButton(key: ValueKey('row-more-\$id'), onPressed: menu);
// parity: row-more-
final row = GestureDetector(onLongPress: menu, child: tile);
final spoken = Semantics(onLongPress: toggle, child: row);
''';
    expect(parityOffenders('planted.dart', paired), isEmpty);
  });
}
