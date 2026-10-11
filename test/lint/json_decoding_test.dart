// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2387 — the data layer decodes rows through ONE reader
// (lib/core/data/json_reader.dart): a missing or mistyped column throws a
// JsonShapeException naming the RPC, the key and the expected type,
// instead of a `type 'Null' is not a subtype` from a screen.
//
// Two ratchets count what is left to move — they only go down — and one
// rule holds the line strict-casts drew: no hand-written file switches
// the cast check off.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Raw `json['…']` reads left in hand-written lib/ (473 lines when the reader
/// landed).
const _rawReadBudget = 473;

/// `factory X.fromJson` in files that do not read through JsonReader (78
/// when the reader landed).
const _handFromJsonBudget = 78;

void main() {
  final files = handWrittenDartFiles('lib').toList();

  test('no cast_nullable_to_non_nullable ignore in hand-written lib/', () {
    final hits = scanLines(
      files,
      (line) => line.contains('cast_nullable_to_non_nullable'),
      skipComments: false,
    );
    expect(
      hits,
      isEmpty,
      reason:
          'read the field through JsonReader instead:\n'
          '${hits.join('\n')}',
    );
  });

  test('raw json reads only go down (ratchet)', () {
    final reads = scanLines(files, (line) => line.contains("json['"));
    final count = reads.length;
    expect(
      count,
      lessThanOrEqualTo(_rawReadBudget),
      reason:
          'decode new rows with JsonReader (lib/core/data/json_reader.dart)',
    );
    expect(
      count,
      _rawReadBudget,
      reason:
          'fewer raw reads than the budget: lower _rawReadBudget to '
          '$count so the win stays',
    );
  });

  test('hand fromJson factories only go down (ratchet)', () {
    final factory = RegExp(r'factory\s+\w+\.fromJson\b');
    final hand = scanLines(
      files.where(
        (f) => !f.readAsStringSync().contains('core/data/json_reader.dart'),
      ),
      factory.hasMatch,
    );
    expect(
      hand.length,
      lessThanOrEqualTo(_handFromJsonBudget),
      reason: 'read the row through JsonReader:\n${hand.join('\n')}',
    );
    expect(
      hand.length,
      _handFromJsonBudget,
      reason:
          'fewer hand factories than the budget: lower '
          '_handFromJsonBudget to ${hand.length} so the win stays',
    );
  });
}
