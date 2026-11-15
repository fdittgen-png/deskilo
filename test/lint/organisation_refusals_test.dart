// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — the app says the organisation's refusals in words by matching the
// server's sentences (`SupabaseOrganisationRepository.refusalOf`). A migration
// that rewords one would silently turn that refusal into "could not be
// changed". Each sentence the app matches is found in the latest definition
// of an organisation function in the migrations.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

const _repository =
    'lib/features/workspace/data/supabase_organisation_repository.dart';

/// The sentences `refusalOf` matches, as written in [source].
List<String> matchedSentences(String source) => [
  for (final m in RegExp(r"\(_, '([^']+)'\)").allMatches(source)) m.group(1)!,
];

final _definition = RegExp(
  r'create or replace function public\.(\w*organisation\w*)\s*\(',
  caseSensitive: false,
);

/// The latest definition of each organisation function in [migrations]
/// (path → text, read in their order), by name.
Map<String, String> latestDefinitions(Map<String, String> migrations) {
  final latest = <String, String>{};
  for (final path in migrations.keys.toList()..sort()) {
    final text = migrations[path]!;
    final starts = _definition.allMatches(text).toList();
    for (final (i, m) in starts.indexed) {
      final end = i + 1 < starts.length ? starts[i + 1].start : text.length;
      latest[m.group(1)!] = text.substring(m.start, end);
    }
  }
  return latest;
}

/// The [sentences] none of [definitions] says.
List<String> unsaid(List<String> sentences, Map<String, String> definitions) {
  final bodies = definitions.values.join('\n');
  return [
    for (final s in sentences)
      if (!bodies.contains("'$s'")) s,
  ];
}

void main() {
  final sentences = matchedSentences(File(_repository).readAsStringSync());
  final definitions = latestDefinitions({
    for (final f in filesUnder(['supabase/migrations'], suffix: '.sql'))
      f.path: f.readAsStringSync(),
  });

  test('the app matches the server\'s sentences', () {
    expect(sentences, isNotEmpty, reason: 'refusalOf matches no sentence');
    expect(definitions, isNotEmpty, reason: 'no organisation function found');
  });

  test('every sentence the app matches is one the server says', () {
    expect(
      unsaid(sentences, definitions),
      isEmpty,
      reason:
          'a migration reworded a refusal the app reads: change refusalOf '
          'with it, or the refusal reads "could not be changed"',
    );
  });

  test('a planted sentence nobody says is found', () {
    expect(unsaid(['an organisation needs a better name'], definitions), [
      'an organisation needs a better name',
    ]);
  });
}
