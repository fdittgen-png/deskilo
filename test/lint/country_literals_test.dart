// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- a rule of one country belongs in that country's add-on
// (`packages/deskilo_jurisdiction_<cc>`), behind a contract surface. This
// counts, per file OUTSIDE those packages, the places where code decides by an
// ISO 3166-1 alpha-2 country code. The count is deliberately blunt: EVERY
// string literal whose value is exactly one two-letter code (`'IT'`, `"FR"`,
// `'EL'`, `'XI'`, `'UK'`) counts, in a comparison, a switch arm, a set or list,
// a map key, a method call -- whatever shape it takes, so no rewriting of the
// rule can hide it. The literals come from the Dart analyzer's parser (the one
// tool/code_health.dart uses), so comments, triple-quoted and raw strings and
// interpolations are read as Dart reads them, never by a hand-written scanner. The UNCL5305
// tax category `'AE'` (reverse charge) is also a code: the files that use it as
// a category are allow-listed with that reason, file by file.
//
// TWO LISTS, in `test/lint/country_literals_baseline.txt`:
//   [checklist]  the files of the #3429 checklist (and their siblings): each
//                must reach 0, and is deleted from the list when it does. A
//                checklist file may not be moved to [allowed].
//   [allowed]    every other file with its CURRENT count and a reason it is not
//                a rule of one country (data, a standard, a category code...).
//                A reason that does not hold up becomes a new checklist item,
//                never a silent entry here.
// Both only FALL; a file in neither has a baseline of 0, so a NEW comparison
// anywhere fails. `UPDATE_COUNTRY_LITERALS=1` rewrites the counts (keeping the
// notes), refused under CI; a new file gets the note `TODO`, which the test
// rejects until a real one replaces it.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _baselinePath = 'test/lint/country_literals_baseline.txt';

/// The files the #3429 checklist names (or that belong to one of its items),
/// by path. A file here is never allow-listed: it goes to 0.
const _checklistFiles = <String>{
  'packages/deskilo_invoice_model/lib/src/vat_compliance.dart',
  'packages/deskilo_invoice_model/lib/src/invoice_ubl_check.dart',
  'packages/deskilo_invoice_model/lib/src/vat_regime.dart',
  'lib/features/money/domain/verifactu.dart',
  'lib/features/money/domain/vat_register_es.dart',
  'lib/features/money/domain/vat_register_es_sii.dart',
  'lib/features/money/application/vat_register_files.dart',
  'packages/deskilo_invoice_model/lib/src/invoice_clauses.dart',
  'lib/features/money/domain/report_data.dart',
  'lib/features/money/domain/swiss_qr_bill_pdf.dart',
  'lib/features/money/domain/swiss_qr_bill_invoice.dart',
  'packages/deskilo_invoice_model/lib/src/swiss_qr_bill.dart',
  'lib/features/money/domain/vat_registers.dart',
  'lib/features/money/domain/archive_bundle.dart',
  'lib/features/money/domain/readable_handover.dart',
  'lib/features/money/application/jurisdiction/filing_context_builder.dart',
  'lib/features/money/presentation/screens/legal_identity_screen.dart',
  'lib/features/money/presentation/screens/vat_declarations_screen.dart',
  'lib/features/money/presentation/vat_filing_file_actions.dart',
  'lib/features/money/presentation/widgets/vat_tax_point_notice.dart',
  'lib/features/money/domain/fr_ereporting.dart',
  'lib/features/money/domain/mtd_boxes.dart',
  'lib/features/money/domain/records_location.dart',
  'lib/core/vat/retention.dart',
  'lib/features/money/domain/vat_register_es_347.dart',
  'lib/features/money/domain/datev.dart',
  'lib/features/money/domain/datev_revenue.dart',
  'lib/features/money/domain/fec_accounts.dart',
  'lib/features/money/domain/fec_lettering.dart',
  'lib/features/money/domain/fec_writer.dart',
};

/// ISO 3166-1 alpha-2 codes, and `EL`/`XI`/`UK`: the VAT-number prefixes and
/// the common spelling the application also uses.
const _iso =
    'AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BV BW BY BZ '
    'CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR '
    'GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO '
    'JP KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR '
    'MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO '
    'RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV '
    'TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS YE YT ZA ZM ZW EL XI UK';

final _isoCodes = _iso.split(' ').toSet();

class _CodeCounter extends RecursiveAstVisitor<void> {
  int count = 0;

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (_isoCodes.contains(node.value)) count++;
    super.visitSimpleStringLiteral(node);
  }
}

/// The number of string literals of [source] whose value is exactly an ISO
/// country code: parsed, so comments and every string shape are Dart's own.
int countryComparisons(String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final counter = _CodeCounter();
  unit.accept(counter);
  return counter.count;
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
    final n = countryComparisons(f.readAsStringSync());
    if (n > 0) out[path] = n;
  }
  return out;
}

typedef _Entry = ({int count, String note});

/// The two lists of the baseline file.
({Map<String, _Entry> checklist, Map<String, _Entry> allowed}) _baseline() {
  final checklist = <String, _Entry>{};
  final allowed = <String, _Entry>{};
  var into = checklist;
  for (final l in File(_baselinePath).readAsLinesSync()) {
    if (l.trim().isEmpty || l.startsWith('#')) continue;
    if (l == '[checklist]') {
      into = checklist;
    } else if (l == '[allowed]') {
      into = allowed;
    } else {
      final parts = l.split(' :: ');
      into[parts[0]] = (count: int.parse(parts[1]), note: parts.skip(2).join(' :: '));
    }
  }
  return (checklist: checklist, allowed: allowed);
}

void main() {
  int count(String statements) => countryComparisons('void f() { $statements }');

  test('the matcher counts every string literal that is an ISO code, whatever '
      'the context', () {
    // comparison, membership, method call, arm, key, mixed collection
    expect(count("if (c == 'IT') {}"), 1);
    expect(count("if ({'CA', 'FR'}.contains(c)) {}"), 2);
    expect(count("if (c.startsWith('ES')) {}"), 1);
    expect(count("final x = switch (c) { 'IT' => 1, _ => 0 };"), 1);
    expect(count("final m = {'IT': 1, 'ES': 2};"), 2);
    expect(count("final s = {'FR', 'DE', extra, ...rest};"), 2);
    // multiline
    expect(count("final s = [\n 'AT',\n 'BE',\n];"), 2);
    expect(count("final x = switch ((c,\n k)) {\n ('FR',\n 'S') => 1, _ => 0 };"), 1);
    // both quote styles, escapes, raw and adjacent strings
    expect(count('if (c == "IT" || c == \'ES\') {}'), 2);
    expect(count("final a = r'IT';"), 1);
    expect(count("final a = 'I' 'T';"), 0);
    // comments are dropped: full-line, inline, block, between tokens
    expect(count("// if (c == 'IT') {}"), 0);
    expect(count("final a = 1; // c == 'IT'"), 0);
    expect(count("final a = 1; /* c == 'IT' */ final b = 2;"), 0);
    expect(count("final b = c == /* the country */ 'IT';"), 1);
    expect(count("/* a\n 'IT'\n */ if (c == 'ES') {}"), 1);
    // a `//` inside a string is not a comment
    expect(count("final u = 'https://x'; if (c == 'IT') {}"), 1);
    // a triple-quoted string with an apostrophe or a quote does not fool it
    final tq = "'" * 3;
    final dq = '"' * 3;
    expect(count("final t = ${tq}it's a 'IT' text$tq; if (c == 'ES') {}"), 1);
    expect(count('final t = ${dq}say "FR" now$dq; if (c == "ES") {}'), 1);
    // nested interpolation: the literals inside it count, the text around not
    expect(count(r'''final s = 'x ${c == 'IT' ? "ES" : 'y'} z';'''), 2);
    expect(count(r'''final s = '${'${'DE'}'}';'''), 1);
    // the VAT-number prefixes and the common spelling count too
    expect(count("final s = {'EL', 'XI', 'UK'};"), 3);
    // not ISO codes: other two-letter strings, longer strings, lower case
    expect(count("final a = ['ZZ', 'Ab', 'it', 'ITA', 'I'];"), 0);
    expect(count("final c = 'Italy';"), 0);
  });

  test('country comparisons outside the add-ons: the checklist goes to 0, the '
      'rest only falls with a reason', () {
    final counts = _counts();
    final base = _baseline();
    if (Platform.environment['UPDATE_COUNTRY_LITERALS'] == '1') {
      expect(Platform.environment['CI'], isNot('true'));
      String line(String path, Map<String, _Entry> from) =>
          '$path :: ${counts[path]} :: ${from[path]?.note ?? 'TODO'}';
      final lines = [
        '# path :: comparisons by ISO country code outside the add-ons :: note (#3429).',
        '# Both lists only fall; see test/lint/country_literals_test.dart.',
        '[checklist]',
        for (final p in (base.checklist.keys.toList()..sort()))
          if ((counts[p] ?? 0) > 0) line(p, base.checklist),
        for (final p in (counts.keys.toList()..sort()))
          if (_checklistFiles.contains(p) && !base.checklist.containsKey(p))
            line(p, {p: (count: 0, note: '#3429 checklist item')}),
        '[allowed]',
        for (final p in (counts.keys.toList()..sort()))
          if (!_checklistFiles.contains(p)) line(p, base.allowed),
      ];
      File(_baselinePath).writeAsStringSync('${lines.join('\n')}\n');
      return;
    }
    final listed = {...base.checklist, ...base.allowed};
    expect(
      listed.length,
      base.checklist.length + base.allowed.length,
      reason: 'a file is on one list only',
    );
    // a checklist file stays on the checklist, an allowed file has a reason
    expect(
      base.allowed.keys.where(_checklistFiles.contains),
      isEmpty,
      reason: 'a #3429 checklist file may not be moved to the allow-list',
    );
    expect(
      [
        for (final e in base.allowed.entries)
          if (e.value.note.trim().length < 15 || e.value.note.startsWith('TODO'))
            e.key,
      ],
      isEmpty,
      reason: 'an allow-listed file needs a reason it is not a country rule',
    );
    final grew = <String>[
      for (final e in counts.entries)
        if (e.value > (listed[e.key]?.count ?? 0))
          '${e.key}: ${listed[e.key]?.count ?? 0} -> ${e.value}',
    ];
    final fell = <String>[
      for (final e in listed.entries)
        if ((counts[e.key] ?? 0) < e.value.count)
          '${e.key}: ${e.value.count} -> ${counts[e.key] ?? 0}',
    ];
    final strayChecklist = <String>[
      for (final p in counts.keys)
        if (_checklistFiles.contains(p) && !base.checklist.containsKey(p)) p,
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
          'progress: lower (or delete) these in $_baselinePath '
          '(UPDATE_COUNTRY_LITERALS=1 rewrites the counts)',
    );
    expect(strayChecklist, isEmpty, reason: 'a checklist file with a count is listed');
  });
}
