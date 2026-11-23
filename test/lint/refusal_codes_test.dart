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

/// #4415 -- the first migration whose run-time refusals all carry a code the app
/// can map: no `P0001`, no bare `22023`, no `42501`, no `28000`, no
/// `exception when others` and no literal `interval '...'` from here on
/// (migration-time asserts, in a `do` block or a `pg_temp` helper, are exempt).
const _mappedFrom = 919;

/// FROZEN BASELINE: the run-time refusals of 0740..0918 that raise a generic
/// SQLSTATE (P0001 and its kin). A migration is immutable, so this number moves
/// only when a migration is ADDED in that range: it must raise a code instead.
/// (They get their code when their functions are next restated, after 0919.)
const _genericFrozen = 289;

/// RATCHET: sentences the booking mapper still reads by their words (the
/// hierarchy guard's 23P01, a taken seat twice, the 42501 permission
/// refusal). Only falls.
const _bookingSentenceBudget = 6;

final _fileName = RegExp(r'^(\d{4})_[a-z0-9_]+\.sql$');
// a statement is cut at a dollar quote: a fragment of one, quoted as an anchor, is no statement
final _raise = RegExp(r'raise\s+exception\b[^;\$]*;', caseSensitive: false);

/// The text a migration quotes as the OLD side of a patch (`\$o\$…\$o\$`): the
/// statement as it stood, not a refusal this migration raises. Before 0919 the
/// tag `\$r\$` served for both sides (0766, 0783) and is read the same way there;
/// from 0919 on only `\$o\$` is old text: a `\$r\$` or `\$n\$` replacement is new code.
final _oldQuote = RegExp(r'\$o\$.*?\$o\$', dotAll: true);
final _legacyQuote = RegExp(r'\$r\$.*?\$r\$', dotAll: true);

/// The blocks that run once at migration time: `do $tag$ ... $tag$;` and a
/// `pg_temp` helper function. A refusal there is an assertion about the
/// migration, never a command's refusal.
final _migrationTime = RegExp(
  r'(?:\bdo\s+(\$\w*\$)[\s\S]*?\1\s*;)|(?:function\s+pg_temp\.\w+\s*\([^$]*?\)[^$]*?(\$\w*\$)[\s\S]*?\2)',
  caseSensitive: false,
);

/// The generic SQLSTATEs a command's refusal never carries: the app reads codes.
final _genericCode = RegExp(
  r"errcode\s*=\s*'(P0001|22023|42501|28000)'"
  r"|sqlstate\s+'(P0001|22023|42501|28000)'"
  r"|raise\s+(raise_exception|insufficient_privilege|invalid_parameter_value|invalid_authorization_specification)\b",
  caseSensitive: false,
);
// any RAISE that is a refusal: not a notice, warning, info, log or debug message
final _raiseAny = RegExp(
  r'raise\s+(?!notice\b|warning\b|info\b|log\b|debug\b)[^;\$]*;',
  caseSensitive: false,
);
final _whenOthers = RegExp(r'exception\s+when\s+others\b', caseSensitive: false);
final _intervalLiteral = RegExp(r"\binterval\s+'", caseSensitive: false);

/// [sql] as the run-time sees it: comments, quoted anchors and migration-time
/// blocks left out.
String runTimeCode(String sql, {bool legacyQuotes = false}) {
  final noBlocks = sql
      .replaceAll(_oldQuote, '')
      .replaceAll(legacyQuotes ? _legacyQuote : RegExp('(?!)'), '')
      .replaceAll(_migrationTime, '');
  return noBlocks
      .split('\n')
      .map((l) => l.contains('--') ? l.substring(0, l.indexOf('--')) : l)
      .join('\n');
}

/// The run-time `raise` statements of [sql] with a generic SQLSTATE or condition.
List<String> genericRaises(String sql, {bool legacyQuotes = false}) => [
  for (final m in _raiseAny.allMatches(runTimeCode(sql, legacyQuotes: legacyQuotes)))
    if (_genericCode.hasMatch(m.group(0)!)) m.group(0)!.replaceAll(RegExp(r'\s+'), ' '),
];

/// `exception when others` handlers and literal intervals of the run-time code.
int whenOthersCount(String sql) => _whenOthers.allMatches(runTimeCode(sql)).length;
int intervalLiteralCount(String sql) => _intervalLiteral.allMatches(runTimeCode(sql)).length;

/// The `raise exception` statements of [sql] without an errcode, comments
/// and anchor quotes left out.
List<String> uncodedRaises(String sql, {bool legacyQuotes = true}) {
  final code = sql
      .replaceAll(_oldQuote, '')
      .replaceAll(legacyQuotes ? _legacyQuote : RegExp('(?!)'), '')
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
    expect(
      uncodedRaises(r"anchor_replace(v_def, $r$raise exception 'old';$r$,"),
      isEmpty,
    );
    },
  );

  test('every refusal of a migration from 0740 on names its code', () {
    final found = <String>[];
    for (final file in sqlFiles('supabase/migrations')) {
      final name = file.uri.pathSegments.last;
      final m = _fileName.firstMatch(name);
      if (m == null || int.parse(m.group(1)!) < _from) continue;
      for (final raise in uncodedRaises(
        file.readAsStringSync(),
        legacyQuotes: int.parse(m.group(1)!) < _mappedFrom,
      )) {
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

  test('a generic code, a catch-all and a literal interval are seen at run time only', () {
    expect(
      genericRaises("create function f() returns void as \$f\$ begin raise exception 'x' using errcode = 'P0001'; end \$f\$;"),
      hasLength(1),
    );
    expect(genericRaises("raise exception 'x' using errcode = '22023';"), hasLength(1));
    expect(genericRaises("raise exception 'x' using errcode = 'DKG07';"), isEmpty);
    expect(
      genericRaises("do \$a\$ begin raise exception 'x' using errcode = 'P0001'; end \$a\$;"),
      isEmpty,
    );
    expect(
      genericRaises("create function pg_temp.patch() returns void as \$f\$ begin raise exception 'x' using errcode = 'P0001'; end \$f\$;"),
      isEmpty,
    );
    // the forms of a generic refusal beside `errcode = 'P0001'`
    expect(genericRaises("raise sqlstate 'P0001' using message = 'x';"), hasLength(1));
    expect(genericRaises("raise using errcode = '42501', message = 'x';"), hasLength(1));
    expect(genericRaises("raise raise_exception using message = 'x';"), hasLength(1));
    expect(genericRaises("raise insufficient_privilege;"), hasLength(1));
    expect(genericRaises("raise invalid_parameter_value using message = 'x';"), hasLength(1));
    expect(genericRaises("raise notice 'x'; raise warning 'y';"), isEmpty);
    expect(genericRaises("raise exception 'x' using errcode = 'DKG07';"), isEmpty);
    // an old-text quote is not new code; a replacement quote is
    expect(genericRaises(r"patch($o$raise exception 'x' using errcode = 'P0001';$o$, $n$b$n$)"), isEmpty);
    expect(genericRaises(r"patch($o$a$o$, $r$raise exception 'x' using errcode = 'P0001';$r$)"), hasLength(1));
    expect(
      genericRaises(r"patch($r$raise exception 'x' using errcode = 'P0001';$r$, $r$b$r$)", legacyQuotes: true),
      isEmpty,
      reason: 'before 0919 the tag r quoted both sides',
    );
    expect(whenOthersCount("begin x; exception when others then y; end;"), 1);
    expect(whenOthersCount("-- exception when others"), 0);
    expect(intervalLiteralCount("now() + interval '5 minutes'"), 1);
    expect(intervalLiteralCount("make_interval(days => 3)"), 0);
  });

  test('a migration from 0919 on refuses with a mapped code, handles no catch-all and states no literal interval', () {
    final found = <String>[];
    var generic = 0;
    for (final file in sqlFiles('supabase/migrations')) {
      final name = file.uri.pathSegments.last;
      final m = _fileName.firstMatch(name);
      if (m == null) continue;
      final n = int.parse(m.group(1)!);
      final sql = file.readAsStringSync();
      if (n < _from) continue;
      if (n < _mappedFrom) {
        generic += genericRaises(sql, legacyQuotes: true).length;
        continue;
      }
      for (final r in genericRaises(sql)) {
        found.add('$name: $r');
      }
      if (whenOthersCount(sql) > 0) found.add('$name: exception when others');
      if (intervalLiteralCount(sql) > 0) found.add("$name: a literal interval '...'");
    }
    expect(
      found,
      isEmpty,
      reason:
          "raise with a DK code (public.refuse(code, detail)), name the "
          "interval in a setting, handle a named exception: the app maps "
          "codes (#4415)",
    );
    expect(
      generic,
      _genericFrozen,
      reason: 'a migration was added before 0919 with a generic refusal: it raises a DK code '
          '(or the number is moved on purpose: $generic)',
    );
  });

  test('the booking refusal reads no more sentences than before', () {
    // #4156 — the words the server's refusal is read by when it has no code of
    // its own: one bounded place, the pure refusal value (the booking mapper's
    // four, the kiosk's two).
    final source = handWrittenDartFiles('lib/features/reservations/domain')
        .singleWhere((f) => f.path.endsWith('/reservation_refusal.dart'))
        .readAsStringSync();
    final sentences = 'words.contains('.allMatches(source).length;
    expect(
      sentences,
      lessThanOrEqualTo(_bookingSentenceBudget),
      reason:
          'give the refusal a code in its migration and map the code '
          '(booking_error_text.dart)',
    );
    expect(
      sentences,
      _bookingSentenceBudget,
      reason: 'it fell: lower _bookingSentenceBudget to $sentences',
    );
  });
}
