// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429, #3516 -- the string literals of a Dart source that are exactly an ISO
// 3166-1 alpha-2 country code, WITH their positions. The lint
// (test/lint/country_literals_test.dart) counts them; the coverage check
// (tool/country_coverage.dart) asks which changed ones no test ran.
//
// The literals come from the analyzer's parser, so comments, doc comments,
// triple-quoted and raw strings and interpolations are read as Dart reads them,
// never by a scanner of our own.
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

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

final Set<String> isoCountryCodes = _iso.split(' ').toSet();

/// One country-code literal. [line] and [endLine] are its own lines (1-based);
/// [anchorLine] is the first line of the statement (or switch case, or switch
/// expression arm) that holds it, or the declaration line of the function body
/// that holds it; null for a field, top-level or default-value initializer:
/// where the coverage tool records a hit for a
/// literal on a continuation line that has no record of its own.
class CountryLiteral {
  const CountryLiteral(this.line, this.endLine, this.anchorLine);
  final int line;
  final int endLine;
  final int? anchorLine;
}

class _Collector extends RecursiveAstVisitor<void> {
  _Collector(this.unit);
  final CompilationUnit unit;
  final found = <CountryLiteral>[];

  int _line(int offset) => unit.lineInfo.getLocation(offset).lineNumber;

  /// The line coverage records for [node]: the first line of the statement,
  /// switch case or switch-expression arm that holds it; else, inside a
  /// function, method, getter or constructor BODY (a multi-line `=>`), the
  /// declaration's name line. A field or top-level initializer and a default
  /// parameter value have none: they run at load time or not at all, and stay
  /// "not executable" for the coverage check.
  int? _anchor(AstNode node) {
    var sawBody = false;
    for (AstNode? up = node.parent; up != null; up = up.parent) {
      if (up is Statement || up is SwitchMember || up is SwitchExpressionCase) {
        return _line(up.offset);
      }
      if (up is FunctionBody) sawBody = true;
      if (sawBody) {
        if (up is MethodDeclaration) return _line(up.name.offset);
        if (up is FunctionDeclaration) return _line(up.name.offset);
        if (up is ConstructorDeclaration) {
          return _line(up.firstTokenAfterCommentAndMetadata.offset);
        }
      }
      if (up is FieldDeclaration || up is TopLevelVariableDeclaration) {
        return null;
      }
    }
    return null;
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (isoCountryCodes.contains(node.value)) {
      found.add(CountryLiteral(_line(node.offset), _line(node.end), _anchor(node)));
    }
    super.visitSimpleStringLiteral(node);
  }
}

/// The country-code literals of [source], in source order.
List<CountryLiteral> countryLiterals(String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final collector = _Collector(unit);
  unit.accept(collector);
  return collector.found;
}

/// The number of string literals of [source] whose value is exactly an ISO
/// country code: parsed, so comments and every string shape are Dart's own.
int countryComparisons(String source) => countryLiterals(source).length;
