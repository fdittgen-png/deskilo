// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3652 — a sentence is one message, not pieces joined in code. A string
// literal that interpolates a translated read beside another interpolation
// builds a sentence from fragments: word order, spacing before punctuation
// and agreement cannot be right in five languages. The sentence is ONE ARB
// message with placeholders (and a plural where there is a count); the
// ` · ` join of independent facts stays allowed.
//
// A ratchet, not an amnesty: `sentence_joins_baseline.txt` records the joins
// that still exist, per file. More is a defect; fewer must be recorded, so
// the list only shrinks toward empty.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';
import 'sentence_joins.dart';

const _baselinePath = 'test/lint/sentence_joins_baseline.txt';

Map<String, int> _baseline() => {
  for (final line in File(_baselinePath).readAsLinesSync())
    if (line.trim().isNotEmpty && !line.startsWith('#'))
      line.split(' ').first: int.parse(line.split(' ').last),
};

void main() {
  test('no new sentence is joined from translated pieces', () {
    final found = <String, int>{};
    final detail = <String, List<String>>{};
    for (final f in handWrittenDartFiles('lib')) {
      final hits = sentenceJoins(f.readAsStringSync());
      if (hits.isNotEmpty) {
        found[f.path] = hits.length;
        detail[f.path] = hits;
      }
    }
    final baseline = _baseline();
    final wrong = <String>[];
    for (final path in {...found.keys, ...baseline.keys}) {
      final now = found[path] ?? 0;
      final allowed = baseline[path] ?? 0;
      if (now != allowed) {
        wrong.add(
          '$path: $now found, $allowed in the baseline'
          '${now > allowed ? '\n  ${detail[path]!.join('\n  ')}' : ''}',
        );
      }
    }
    expect(
      wrong,
      isEmpty,
      reason:
          'Make the sentence one ARB message with placeholders '
          '(l10n.someKey(value)) instead of joining pieces in code. When a '
          'join is removed, lower its count in $_baselinePath.\n'
          '${wrong.join('\n')}',
    );
  });
}
