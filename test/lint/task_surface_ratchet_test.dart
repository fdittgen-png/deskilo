// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3608 (desk K3) — a form opens as a task (`showTask`, or `showAppFormSheet`
// which is one), so that at the desk it is a side panel or a dialog and not a
// phone sheet at the bottom of a wide window. The forms still opened by a
// direct `showAppSheet` call only ever fall.
//
// What is counted: a `showAppSheet(` call outside lib/core/ui whose
// arguments carry a text field — written in the call itself, or in the file
// that declares a widget the call builds. A text field is the kit's
// (`AppTextField`, `AmountField`, `DateField`) or a raw `TextField` /
// `TextFormField`. Counted per call, so moving a call to `showTask` lowers
// the number by one.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Measured 2026-11-11 on the branch that introduced `showTask`.
const int _formSheetCeiling = 22;

final _call = RegExp(r'\bshowAppSheet\s*(<[^(]*>)?\s*\(');
final _field = RegExp(
  r'\b(AppTextField|AmountField|DateField|TextField|TextFormField)\s*\(',
);
final _built = RegExp(r'\b([A-Z]\w*)\s*(?:<[^(]*>)?\s*\(');
final _declared = RegExp(
  r'^(?:abstract\s+|final\s+)?class\s+(\w+)',
  multiLine: true,
);

/// The text of the call's arguments: from its `(` to the matching `)`.
String _arguments(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (c == '(') depth++;
    if (c == ')' && --depth == 0) return code.substring(open, i + 1);
  }
  return code.substring(open);
}

String _code(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// The direct `showAppSheet` calls that carry a form, as `path: n`.
List<String> formSheetCalls() {
  final files = handWrittenDartFiles('lib').toList();
  final code = {for (final f in files) f.path: _code(f)};
  final withField = <String, bool>{
    for (final e in code.entries) e.key: _field.hasMatch(e.value),
  };
  final declaredIn = <String, String>{
    for (final e in code.entries)
      for (final m in _declared.allMatches(e.value)) m.group(1)!: e.key,
  };
  final found = <String>[];
  for (final e in code.entries) {
    if (e.key.startsWith('lib/core/ui/')) continue;
    for (final m in _call.allMatches(e.value)) {
      final args = _arguments(e.value, m.end - 1);
      final carries =
          _field.hasMatch(args) ||
          _built
              .allMatches(args)
              .map((b) => declaredIn[b.group(1)])
              .any((path) => path != null && withField[path]!);
      if (carries) found.add('${e.key}:${m.start}');
    }
  }
  return found;
}

void main() {
  test('direct showAppSheet calls that carry a form only ever fall', () {
    final calls = formSheetCalls();
    expect(
      calls.length,
      lessThanOrEqualTo(_formSheetCeiling),
      reason:
          'A form opened by showAppSheet grew the count to ${calls.length} '
          '(ceiling $_formSheetCeiling). Open it with showTask '
          '(lib/core/ui/adaptive/task_surface.dart) or showAppFormSheet.',
    );
    expect(
      calls.length,
      _formSheetCeiling,
      reason:
          'The count fell to ${calls.length} — lower the ceiling to '
          '${calls.length} in this commit.',
    );
  });
}
