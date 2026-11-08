// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- a rule of one country belongs in that country's add-on
// (`packages/deskilo_jurisdiction_<cc>`), behind a contract surface. This
// counts, per file OUTSIDE those packages, the places where code decides by an
// ISO 3166-1 alpha-2 country code: `== 'XX'`, `!= 'XX'`, `case 'XX'`, a
// `'XX' =>` switch arm and `'XX':` map-key arms of a switch-like table are
// counted as comparisons (a bare mention in a list or a message is not).
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
/// application also compares), without `AE`: that is the UNCL5305 tax
/// category of a reverse charge far more often than the Emirates.
const _iso =
    'AD AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BV BW BY BZ '
    'CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR '
    'GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO '
    'JP KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR '
    'MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO '
    'RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV '
    'TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS YE YT ZA ZM ZW EL XI UK';

final _codes = _iso.split(' ').join('|');

/// The comparison shapes: a code beside `==`/`!=`, after `case`, or as a switch
/// arm head.
final _patterns = <RegExp>[
  RegExp("(?:==|!=)\\s*'(?:$_codes)'"),
  RegExp("'(?:$_codes)'\\s*(?:==|!=)"),
  RegExp("\\bcase\\s+'(?:$_codes)'"),
  RegExp("'(?:$_codes)'\\s*(?:\\|\\s*'(?:$_codes)'\\s*)*=>"),
];

/// The number of comparisons in [source], comments dropped.
int countryComparisons(String source) {
  var n = 0;
  for (final line in source.split('\n')) {
    final code = line.trimLeft().startsWith('//') ? '' : line;
    for (final p in _patterns) {
      n += p.allMatches(code).length;
    }
  }
  return n;
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
    final n = countryComparisons(f.readAsStringSync());
    if (n > 0) out[f.path.replaceFirst(RegExp(r'^.*?(?=(lib|packages)/)'), '')] = n;
  }
  return out;
}

Map<String, int> _baseline() => {
  for (final l in File(_baselinePath).readAsLinesSync())
    if (l.trim().isNotEmpty && !l.startsWith('#'))
      l.split(' :: ').first: int.parse(l.split(' :: ').last),
};

void main() {
  test('the matcher counts comparisons and nothing else', () {
    expect(countryComparisons("if (c == 'IT') {}"), 1);
    expect(countryComparisons("if ('IT' != c) {}"), 1);
    expect(countryComparisons("switch (c) { case 'ES': 1; case 'FR': 2; }"), 2);
    expect(countryComparisons("final x = switch (c) { 'IT' => 1, 'ES' || 'FR' => 2, _ => 0 };"), 2);
    expect(countryComparisons("final l = ['IT', 'ES'];"), 0);
    expect(countryComparisons("// if (c == 'IT') {}"), 0);
    expect(countryComparisons("if (c == 'ZZ') {}"), 0);
    expect(countryComparisons("final m = {'IT': 1};"), 0);
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
