// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3488 -- a name list is sorted with `compareNames` (lib/core/text), not
// with Dart's UTF-16 `compareTo`, which puts every accented initial after Z.
// Counted, not listed: the ceiling is 0 and a hit names its file. #4428: a
// map's values that are names (`entries..sort((a, b) => a.value.compareTo(…))`)
// sort the same way, and a search in a screen folds case and accents with
// `foldForSearch` instead of lower-casing, so `cafe` finds `Café`.
import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

final _kinds = [
    LiteralKind(
      'lower-cased compareTo',
      RegExp(r'toLowerCase\(\)\s*\.compareTo\('),
    ),
    // #3654 -- the multi-line and the map-lookup shapes.
    LiteralKind(
      'person-name compareTo',
      RegExp(r'\.(memberName|fullName|displayName|firstName|lastName)\s*\.compareTo\('),
    ),
    LiteralKind(
      'name lookup compareTo',
      RegExp(r"names\[[^\]]+\]\s*\?\?\s*''\)\s*\.compareTo\("),
    ),
    LiteralKind(
      'name compareTo',
      RegExp(r'\.(name|title|label|displayName)\.compareTo\('),
    ),
  // #3654 -- a call's result compared (`localizedName(l10n, a)\n.compareTo(`).
  LiteralKind(
    'name call compareTo',
    RegExp(r'\b\w*[Nn]ame\w*\([^()]*\)\s*\.compareTo\('),
  ),
  LiteralKind(
    'entry value compareTo',
    RegExp(r'\.value\s*\.compareTo\('),
  ),
];

/// A search that lower-cases instead of folding (#4428).
final _search = LiteralKind(
  'lower-cased search',
  RegExp(r'toLowerCase\(\)\s*\.contains\('),
);

void main() {
  test('no client-side name sort uses compareTo on a name', () {
    final files = filesUnder(['lib'])
        .where((f) => !f.path.startsWith('lib/core/text/'));
    final kinds = _kinds;
    final counted = countLiterals(files, kinds);
    for (final k in kinds) {
      final perFile = counted[k.name]!;
      expect(
        total(perFile),
        0,
        reason: ratchetMessage(
          rule: 'name sorting (#3488): use compareNames from lib/core/text/collation.dart',
          kind: k.name,
          ceiling: 0,
          actual: total(perFile),
          perFile: perFile,
        ),
      );
    }
  });

  // Every layer, not only screens: a domain or application filter (the
  // features list, Me's spaces, the time zones) searches for a person too.
  // Exempt: lib/core/backend matches a server's English error text, and the
  // Demo's fakes answer as the server's own search does.
  test('a search folds case and accents (#4428)', () {
    final files = filesUnder(['lib']).where(
      (f) =>
          !f.path.startsWith('lib/core/backend/') &&
          !f.path.startsWith('lib/core/demo/') &&
          !f.path.startsWith('lib/core/text/'),
    );
    final perFile = countLiterals(files, [_search])[_search.name]!;
    expect(
      total(perFile),
      0,
      reason: ratchetMessage(
        rule: 'search (#4428): compare foldForSearch(text).contains(foldForSearch(query)) from lib/core/text/collation.dart',
        kind: _search.name,
        ceiling: 0,
        actual: total(perFile),
        perFile: perFile,
      ),
    );
    expect(_search.pattern.hasMatch('name.toLowerCase()\n    .contains(q)'), isTrue);
    expect(_search.pattern.hasMatch('foldForSearch(name).contains(q)'), isFalse);
  });

  test('the patterns see a split receiver and a wrapped call (#3654)', () {
    const planted = [
      "a.memberName\n    .toLowerCase()\n    .compareTo(b.memberName)",
      "(names[a.id] ?? '')\n    .compareTo(names[b.id] ?? '')",
      "localizedCountryName(\n  l10n,\n  a,\n).compareTo(x)",
      "localizedCountryName(l10n, a)\n    .compareTo(x)",
      '..sort((a, b) => a.value.compareTo(b.value))',
    ];
    for (final text in planted) {
      expect(
        _kinds.any((k) => k.pattern.hasMatch(text)),
        isTrue,
        reason: text,
      );
    }
    expect(_kinds.any((k) => k.pattern.hasMatch('a.id.compareTo(b.id)')), isFalse);
  });
}
