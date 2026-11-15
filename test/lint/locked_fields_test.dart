// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4020 — a fact that cannot be edited is text, not a disabled field: a
// screen reader announces a field that does nothing, and the eye reads a form
// where there is none. A text field stays locked (`enabled: false`,
// `readOnly: true`) only for a reason written on the line
// (`// field-locked: <why>`), and their number only falls.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

/// The text fields a lock can sit on.
const _fields = {
  'TextField',
  'TextFormField',
  'AppTextField',
  'WorkspaceFieldsSection',
};

/// Locked text fields with their reason, measured on 15 Nov 2026.
const _ceiling = 5;

final _lock = RegExp(r'\b(enabled:\s*false|readOnly:\s*true)');

/// The name of the call whose argument list holds [offset] in [text].
String? _enclosingCall(String text, int offset) {
  var depth = 0;
  for (var i = offset - 1; i >= 0; i--) {
    final c = text[i];
    if (c == ')') depth++;
    if (c == '(') {
      if (depth == 0) {
        final m = RegExp(r'(\w+)\s*$').firstMatch(text.substring(0, i));
        return m?.group(1);
      }
      depth--;
    }
  }
  return null;
}

/// Each lock on a text field in [text]: its line, and whether it says why.
List<(int, bool)> locksIn(String text) => [
  for (final m in _lock.allMatches(text))
    if (_fields.contains(_enclosingCall(text, m.start)))
      (
        '\n'.allMatches(text.substring(0, m.start)).length + 1,
        text
            .substring(
              m.start,
              text.indexOf('\n', m.start).clamp(0, text.length),
            )
            .contains('field-locked:'),
      ),
];

void main() {
  final found = [
    for (final f in filesUnder(['lib']))
      if (!f.path.endsWith('.g.dart'))
        for (final (line, why) in locksIn(File(f.path).readAsStringSync()))
          (f.path, line, why),
  ];

  test('every locked text field says why on its line', () {
    expect(
      [
        for (final (path, line, why) in found)
          if (!why) '$path:$line',
      ],
      isEmpty,
      reason:
          'a fact is text (a labelled line), not a disabled field; a field '
          'locked for now says why: `// field-locked: <why>`',
    );
  });

  test('locked text fields only fall', () {
    expect(found.length, _ceiling, reason: 'a fall lowers the ceiling here');
  });

  test('the count can fail: a planted lock without a reason is found', () {
    const planted = '''
      TextField(
        controller: c,
        readOnly: true,
      ),
      ListTile(enabled: false, title: Text(t)),
      AppTextField(
        enabled: false, // field-locked: a preview
      ),
    ''';
    expect(locksIn(planted), [(3, false), (7, true)]);
  });
}
