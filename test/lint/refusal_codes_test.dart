// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3810 (part of #3657, i18n I11b) -- a refusal is read by its code, never
// by its sentence. Two rules hold it after 0739:
// - from migration 0740 on, every `raise exception` names its errcode, so a
//   new refusal arrives with a code the app can map;
// - the booking mapper's table of sentences only shrinks: what has a code is
//   read by it, and a sentence is read only where no code exists yet.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The first migration whose refusals all carry a code.
const _from = 740;

/// RATCHET: sentences the booking mapper still reads by their words (the
/// hierarchy guard's 23P01, a taken seat twice, the 42501 permission
/// refusal). Only falls.
const _bookingSentenceBudget = 4;

final _fileName = RegExp(r'^(\d{4})_[a-z0-9_]+\.sql$');
final _raise = RegExp(r'raise\s+exception\b[^;]*;', caseSensitive: false);

/// The `raise exception` statements of [sql] without an errcode, comments
/// left out.
List<String> uncodedRaises(String sql) {
  final code = sql
      .split('\n')
      .map((l) => l.contains('--') ? l.substring(0, l.indexOf('--')) : l)
      .join('\n');
  return [
    for (final m in _raise.allMatches(code))
      if (!m.group(0)!.toLowerCase().contains('errcode'))
        m.group(0)!.replaceAll(RegExp(r'\s+'), ' '),
  ];
}

void main() {
  test(
    'a raise without its code is seen; one with it, or a comment, is not',
    () {
      expect(uncodedRaises("  raise exception 'not yours';"), hasLength(1));
      expect(
        uncodedRaises("  raise exception 'not yours' using errcode = 'DKK29';"),
        isEmpty,
      );
      expect(
        uncodedRaises(
          "raise exception 'beyond % days', d\n    using errcode = 'DKK08';",
        ),
        isEmpty,
      );
      expect(uncodedRaises("-- raise exception 'old';"), isEmpty);
    },
  );

  test('every refusal of a migration from 0740 on names its code', () {
    final found = <String>[];
    for (final file in sqlFiles('supabase/migrations')) {
      final name = file.uri.pathSegments.last;
      final m = _fileName.firstMatch(name);
      if (m == null || int.parse(m.group(1)!) < _from) continue;
      for (final raise in uncodedRaises(file.readAsStringSync())) {
        found.add('$name: $raise');
      }
    }
    expect(
      found,
      isEmpty,
      reason:
          'raise exception ... using errcode = \'DK..\', with its '
          'values as JSON in detail: the app maps codes, never sentences '
          '(#3810)',
    );
  });

  test('the booking mapper reads no more sentences than before', () {
    final source = handWrittenDartFiles('lib/features/reservations/domain')
        .singleWhere((f) => f.path.endsWith('/booking_error_text.dart'))
        .readAsStringSync();
    final sentences = '.contains('.allMatches(source).length;
    expect(
      sentences,
      lessThanOrEqualTo(_bookingSentenceBudget),
      reason:
          'give the refusal a code in its migration and map the code '
          '(booking_refusal_codes.dart)',
    );
    expect(
      sentences,
      _bookingSentenceBudget,
      reason: 'it fell: lower _bookingSentenceBudget to $sentences',
    );
  });
}
