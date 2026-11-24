// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4429 -- a label and its value on one line are joined by the language
// (`l10n.labelledValue(label, value)`: `Total : 12 €` in French), never by a
// literal `': '` after an interpolation in a screen. The scan of
// `sentence_joins` sees a translated read beside a value; this one sees the
// label that comes through a helper. The files that join a label to a value
// on purpose are named with the reason; the count is 0 everywhere else.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// A literal `: ` between two interpolations, or after one and before a value.
final _join = RegExp(r'(\$\{[^}]+\}|\$[A-Za-z_]\w*): \$');

/// Files that keep such a join, and why.
const _allowed = <String, String>{
  'lib/features/money/presentation/bank_reconciliation_words.dart': "a document: the reconciliation report's own word bundle, printed in the report's language",
  'lib/features/money/presentation/widgets/report_layout_preview_dialog.dart': 'a layout error for the person who edits the layout: the error code beside its technical detail',
  'lib/features/workspace/presentation/screens/template_compare_screen.dart':
      "a template's raw configuration: a machine key beside its stored value",
};

void main() {
  test('no screen joins a label to its value with a literal colon', () {
    final files = handWrittenDartFiles('lib').where(
      (f) =>
          (f.path.contains('/presentation/') ||
              f.path.startsWith('lib/app/') ||
              f.path.startsWith('lib/core/ui/')) &&
          !_allowed.containsKey(f.path),
    );
    final hits = scanLines(
      files,
      (line) =>
          _join.hasMatch(line) &&
          !RegExp(r'debugPrint|TraceLogger|throw |Exception\(').hasMatch(line),
    );
    expect(
      hits,
      isEmpty,
      reason:
          'join them with l10n.labelledValue(label, value):\n${hits.join('\n')}',
    );
  });

  test('the join is seen, and the message is not', () {
    expect(_join.hasMatch(r"Text('${fact.label}: ${fact.value}')"), isTrue);
    expect(_join.hasMatch(r"'${words.uxBookingFor}: $person'"), isTrue);
    expect(
      _join.hasMatch('l10n.labelledValue(fact.label, fact.value)'),
      isFalse,
    );
  });
}
