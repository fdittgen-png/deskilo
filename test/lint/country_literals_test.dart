// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- a rule of one country belongs in that country's add-on
// (`packages/deskilo_jurisdiction_<cc>`), behind a contract surface. This
// counts, per file OUTSIDE those packages, the places where code decides by an
// ISO 3166-1 alpha-2 country code: `== 'XX'`, `!= 'XX'`, `case 'XX'`, a
// `'XX' =>` switch arm, a record arm `('XX', _) =>`, `.startsWith/.endsWith/
// .contains('XX')` and a `'XX':` map key (the keys of a per-country table are a
// per-country rule too). A bare mention in a list or a message is not.
//
// RATCHET: every file's count may only FALL. The baseline is
// `test/lint/country_literals_baseline.txt` (`path :: count`); a #3429 item
// takes its files to 0 and deletes their lines. A file not listed has a
// baseline of 0, so a NEW comparison anywhere fails. Rewrite the baseline only
// with `UPDATE_COUNTRY_LITERALS=1`, never under CI; the diff is the review.
//
// Scanned: `lib/` and `packages/*/lib` except `deskilo_jurisdiction_*`;
// generated sources and the localisation catalogue are not hand-written code.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _baselinePath = 'test/lint/country_literals_baseline.txt';

/// ISO 3166-1 alpha-2 codes (and `EL`/`XI`, the VAT-number prefixes the
/// application also compares). `AE` is also the UNCL5305 tax category of a
/// reverse charge: a comparison of a category with it is not counted (below).
const _iso =
    'AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BV BW BY BZ '
    'CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR '
    'GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO '
    'JP KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR '
    'MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO '
    'RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV '
    'TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS YE YT ZA ZM ZW EL XI UK';

final _codes = _iso.split(' ').join('|');

/// A quoted ISO code, in single or double quotes.
final _q = "['\\\"](?:$_codes)['\\\"]";

/// The comparison shapes, matched on the whole comment-free source (a record
/// arm, a literal or a table may span lines).
final _patterns = <RegExp>[
  RegExp("(?:==|!=)\\s*$_q"),
  RegExp("$_q\\s*(?:==|!=)"),
  RegExp("\\bcase\\s+$_q"),
  RegExp("$_q\\s*(?:\\|\\s*$_q\\s*)*=>"),
  // a record arm: `('FR', _) =>`, `(_, 'FR') =>`, `('FR', 'S') =>`
  RegExp("\\([^()]*$_q[^()]*\\)\\s*=>"),
  RegExp("\\.(?:startsWith|endsWith|contains)\\(\\s*$_q\\s*\\)"),
  // a map key (also the arm of a lookup table)
  RegExp("(?<!\\bcase\\s)$_q\\s*:"),
];

/// A list or set literal made of ISO codes (`{'CA', 'FR'}`): every code in it
/// counts, it is a per-country decision list.
final _literal = RegExp("[\\[{]\\s*((?:$_q\\s*,?\\s*)+)[\\]}]");
final _oneCode = RegExp(_q);

/// `category == 'AE'` and the like: the UNCL5305 reverse-charge category, not a
/// country (the Emirates).
final _categoryAe = RegExp(
  "(?:[cC]ategory\\w*|\\bcat)\\s*(?:==|!=)\\s*['\\\"]AE['\\\"]"
  "|['\\\"]AE['\\\"]\\s*(?:==|!=)\\s*\\w*[cC]ategory",
);

/// Files that hold country data, not a rule of one country, each with why.
/// They are not counted. Keep this list short and reasoned.
const _data = <String, String>{
  'lib/core/i18n/country_names.dart':
      'the display names of the countries in every language: a table of names',
  'lib/core/country/country_catalog.dart':
      'the catalogue of the countries the app knows (name, currency, default '
          'locale): data the registry serves, not a rule',
  'lib/core/jurisdiction/jurisdiction_resolver.dart':
      'the registry spelling of a country code (`UK` is `GB`)',
  'lib/features/money/domain/address_window.dart':
      'a postal layout standard, not a jurisdiction rule (coordinator decision, #3403)',
};

/// The code of [source] with comment lines dropped, on one line.
String _codeOf(String source) => source
    .split('\n')
    .where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('//'))
    .map((l) => l.trim())
    .join(' ');

/// The number of comparisons in [source], comments dropped.
int countryComparisons(String source) {
  final code = _codeOf(source);
  var n = 0;
  for (final p in _patterns) {
    n += p.allMatches(code).length;
  }
  for (final m in _literal.allMatches(code)) {
    n += _oneCode.allMatches(m.group(1)!).length;
  }
  return n - _categoryAe.allMatches(code).length;
}

Iterable<File> _scanned() sync* {
  yield* handWrittenDartFiles('lib');
  for (final f in handWrittenDartFiles('packages')) {
    final path = f.path.replaceFirst(RegExp(r'^.*?(?=packages/)'), '');
    if (path.contains('/lib/') &&
        !path.startsWith('packages/deskilo_jurisdiction_')) {
      yield f;
    }
  }
}

Map<String, int> _counts() {
  final out = <String, int>{};
  for (final f in _scanned()) {
    final path = f.path.replaceFirst(RegExp(r'^.*?(?=(lib|packages)/)'), '');
    if (_data.containsKey(path)) continue;
    final n = countryComparisons(f.readAsStringSync());
    if (n > 0) out[path] = n;
  }
  return out;
}

Map<String, int> _baseline() => {
  for (final l in File(_baselinePath).readAsLinesSync())
    if (l.trim().isNotEmpty && !l.startsWith('#'))
      l.split(' :: ').first: int.parse(l.split(' :: ').last),
};

void main() {
  test('the matcher counts each shape of comparison, and nothing else', () {
    expect(countryComparisons("if (c == 'IT') {}"), 1);
    expect(countryComparisons("if ('IT' != c) {}"), 1);
    expect(countryComparisons("switch (c) { case 'ES': 1; case 'FR': 2; }"), 2);
    expect(
      countryComparisons("final x = switch (c) { 'IT' => 1, 'ES' || 'FR' => 2, _ => 0 };"),
      2,
    );
    // record arms, also over several lines
    expect(countryComparisons("switch ((c, k)) { ('FR', _) => 1, (_, 'S') => 2, }"), 1);
    expect(countryComparisons("switch ((c,\n k)) {\n ('FR',\n 'S') => 1 }"), 1);
    // string tests and map keys
    expect(countryComparisons("if (c.startsWith('ES')) {}"), 1);
    expect(countryComparisons("if (c.endsWith('ES') || c.contains('FR')) {}"), 2);
    expect(countryComparisons("final m = {'IT': 1, 'ES': 2};"), 2);
    // double quotes, and codes in set and list literals
    expect(countryComparisons('if (c == "IT") {}'), 1);
    expect(countryComparisons("if ({'CA', 'FR'}.contains(c)) {}"), 2);
    expect(countryComparisons('const eu = ["IT", "ES", "FR"];'), 3);
    expect(countryComparisons("const k = {'IT', 'a'};"), 0);
    // `AE` is a country only when it is not compared with a tax category
    expect(countryComparisons("final t = c.category != 'AE';"), 0);
    expect(countryComparisons("final t = 'AE' == vatCategory;"), 0);
    expect(countryComparisons("if (country == 'AE') {}"), 1);
    // not comparisons
    expect(countryComparisons("final l = ['IT', 'x'];"), 0);
    expect(countryComparisons("final c = Country('DE', 'Germany');"), 0);
    expect(countryComparisons("// if (c == 'IT') {}"), 0);
    expect(countryComparisons("if (c == 'ZZ') {}"), 0);
    expect(countryComparisons("final s = x.startsWith('Italy');"), 0);
  });

  test('country comparisons outside the add-ons only fall', () {
    final counts = _counts();
    if (Platform.environment['UPDATE_COUNTRY_LITERALS'] == '1') {
      expect(Platform.environment['CI'], isNot('true'));
      final lines = [
        '# path :: comparisons by ISO country code, outside the add-ons (#3429).',
        '# A #3429 item takes its files to 0 and deletes their lines.',
        for (final e in (counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
          '${e.key} :: ${e.value}',
      ];
      File(_baselinePath).writeAsStringSync('${lines.join('\n')}\n');
      return;
    }
    final base = _baseline();
    final grew = <String>[
      for (final e in counts.entries)
        if (e.value > (base[e.key] ?? 0))
          '${e.key}: ${base[e.key] ?? 0} -> ${e.value}',
    ];
    final fell = <String>[
      for (final e in base.entries)
        if ((counts[e.key] ?? 0) < e.value)
          '${e.key}: ${e.value} -> ${counts[e.key] ?? 0}',
    ];
    expect(
      grew,
      isEmpty,
      reason:
          'a rule of one country goes behind its add-on\'s contract, not into '
          'a generic file (#3429)',
    );
    expect(
      fell,
      isEmpty,
      reason:
          'progress: lower these in $_baselinePath '
          '(UPDATE_COUNTRY_LITERALS=1 rewrites it)',
    );
  });
}
