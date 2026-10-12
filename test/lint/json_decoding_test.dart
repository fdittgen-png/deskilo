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

/// Raw `json['…']` read lines left in hand-written lib/ (473 when the
/// reader landed, 441 after the money rows, 245 once every fromJson read
/// through it).
const _rawReadBudget = 245;

/// Lines naming `dynamic` in hand-written lib/ (728 in the review of
/// #2381, 684 once every fromJson read through JsonReader, 688 when #2386
/// split the demo repositories: four forwarders repeat a signature). Most are
/// `Map<String, dynamic>` signatures of the decoders; they go as the
/// signatures move to `Map<String, Object?>`.
const _dynamicBudget = 688;

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

  test('every fromJson reads through JsonReader', () {
    // The body of a factory runs to its closing brace at member
    // indentation; generated (`_$XFromJson`) decoders pass too.
    final factory = RegExp(r'factory\s+(\w+)\.fromJson\(');
    final hand = <String>[];
    for (final file in files) {
      final text = file.readAsStringSync();
      for (final m in factory.allMatches(text)) {
        final end = text.indexOf('\n  }\n', m.start);
        final body = text.substring(m.start, end < 0 ? text.length : end);
        if (!body.contains('JsonReader') && !body.contains(r'_$')) {
          hand.add('${file.path}: ${m.group(1)}.fromJson');
        }
      }
    }
    expect(
      hand,
      isEmpty,
      reason:
          'read the row through JsonReader (lib/core/data/json_reader.dart):'
          '\n${hand.join('\n')}',
    );
  });

  test('the dynamic budget only goes down (ratchet)', () {
    final dynamicWord = RegExp(r'\bdynamic\b');
    final count = scanLines(files, dynamicWord.hasMatch).length;
    expect(
      count,
      lessThanOrEqualTo(_dynamicBudget),
      reason: 'type it: JsonReader for a row, Object? for an unknown',
    );
    expect(
      count,
      _dynamicBudget,
      reason:
          'fewer dynamic lines than the budget: lower _dynamicBudget to '
          '$count so the win stays',
    );
  });
}
