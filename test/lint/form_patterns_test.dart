// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Forms are built from the form kit (lib/core/ui/form_kit.dart), not by hand.
// See .claude/skills/deskilo-forms.
//
// The design system stopped at the form field: tokens, radii and colours
// are enforced, but each form chose its own field, spacing and fallback
// text. Measured on master 2026-10-07 (hand-written lib/, generated files
// excluded):
//
//   * raw `TextField(` / `TextFormField(` outside lib/core/ui   — counted
//   * `SizedBox(height: <number>` in presentation code           — counted
//   * `l10n?.key ?? '<English>'` fallbacks                        — counted
//   * an e-mail field without `autofillHints`                     — counted
//
// ## Ratchets, the house mechanism
//
// Nothing here is banned outright: existing forms migrate when they are
// touched. Each number may only FALL. A change that lowers one lowers the
// ceiling in the same commit (the failure says so), so the ground taken is
// kept; a change that raises one is asked to use the kit instead.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Ceilings measured 2026-10-07, then lowered by the expense sheet's move to
/// the kit and the e-mail autofill fixes. Lower them as forms move.
const int _rawFieldCeiling = 207;
const int _literalGapCeiling = 253; // #2286 and #2291 use spacing tokens.
const int _fallbackCeiling =
    6462; // #2287, #2288 and #2291 use localized task groups.
const int _emailWithoutAutofillCeiling = 0;

Iterable<File> _lib() => handWrittenDartFiles('lib');

bool _isKit(String path) => path.startsWith('lib/core/ui/');

bool _isPresentation(String path) =>
    path.contains('/presentation/') || path.startsWith('lib/app/');

final _rawField = RegExp(r'\b(TextField|TextFormField)\(');
final _literalGap = RegExp(r'SizedBox\(\s*height:\s*\d');

/// One `l10n?.key ?? '…'` (or `l10n?.key(arg) ?? '…'`), wherever the
/// formatter breaks the line: counted per fallback, not per line, so
/// reformatting moved code cannot move the number either way.
final _fallback = RegExp(r"l10n\??\.\w+(?:\([^()]*\))?\s*\?\?\s*'");

/// Every match of [pattern] in [files], comment lines left out.
int _matches(Iterable<File> files, RegExp pattern) {
  var n = 0;
  for (final f in files) {
    final code = f
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    n += pattern.allMatches(code).length;
  }
  return n;
}

int _count(Iterable<File> files, RegExp pattern) =>
    scanLines(files, pattern.hasMatch).length;

/// E-mail fields whose call (the next 12 lines) names no autofill hint.
int _emailWithoutAutofill(Iterable<File> files) {
  var n = 0;
  for (final f in files) {
    final lines = f.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].contains('TextInputType.emailAddress')) continue;
      final from = (i - 12).clamp(0, lines.length);
      final to = (i + 12).clamp(0, lines.length);
      final window = lines.sublist(from, to).join('\n');
      // A hint passed straight (`autofillHints:`) or through a form's own
      // helper parameter (`AutofillHints.email`) both count.
      if (!window.contains('autofillHints') &&
          !window.contains('AutofillHints.')) {
        n++;
      }
    }
  }
  return n;
}

void _ratchet(String what, int count, int ceiling) {
  expect(
    count,
    lessThanOrEqualTo(ceiling),
    reason:
        '$what grew to $count (ceiling $ceiling). Build the form with '
        'the form kit (lib/core/ui/form_kit.dart) instead.',
  );
  expect(
    count,
    ceiling,
    reason:
        '$what fell to $count — lower the ceiling to $count in this '
        'commit, so the next change cannot win the ground back.',
  );
}

void main() {
  final files = _lib().toList();
  final outsideKit = files.where((f) => !_isKit(f.path)).toList();
  final presentation = files.where((f) => _isPresentation(f.path)).toList();

  test('raw text fields outside the form kit only ever decrease', () {
    _ratchet(
      'Raw TextField/TextFormField',
      _count(outsideKit, _rawField),
      _rawFieldCeiling,
    );
  });

  test('literal vertical gaps in presentation code only ever decrease', () {
    _ratchet(
      'SizedBox(height: <number>)',
      _count(presentation, _literalGap),
      _literalGapCeiling,
    );
  });

  test('inline English fallbacks only ever decrease', () {
    _ratchet(
      "l10n?.key ?? '<English>'",
      _matches(outsideKit, _fallback),
      _fallbackCeiling,
    );
  });

  test('e-mail fields without autofill hints only ever decrease', () {
    _ratchet(
      'E-mail field without autofillHints',
      _emailWithoutAutofill(outsideKit),
      _emailWithoutAutofillCeiling,
    );
  });
}
