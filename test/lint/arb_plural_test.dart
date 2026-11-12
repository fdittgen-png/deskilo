// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3651, #3743 -- a number in a sentence gets its plural: "1 days" reads wrong
// in every language. The lint reads every message of every one of the five
// languages as a tree and checks EACH number placeholder of it:
//   * a count is inside a plural of its own, in every language (one pluralised
//     and one bare count in the same message is refused; a translation that
//     lost its plural is refused);
//   * a number that is not a count says so in the English description as
//     `[not a count: name, name]`, naming the placeholders and keeping its
//     reason as prose; an exemption that names no placeholder, or one that
//     does not exist, or one a language pluralises, is refused;
//   * a plural uses the language's own categories (`one`, `other`; `=0` only
//     for a sentence that differs for none), never `=1`; French `one` also
//     covers 0, so its form carries the number or an `=0` of its own;
//   * no `(s)` in any language, and no English-only plural logic in code
//     (`count == 1 ? l10n.a : l10n.b`).
// What cannot be fixed yet is the baseline in docs/design/PLURAL_BASELINE.txt
// (`key placeholder language`), which only shrinks.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'icu_message.dart';
import 'lint_sources.dart';

const _languages = ['en', 'de', 'fr', 'es', 'it'];

final _marker = RegExp(r'\[not a count: ([^\]]*)\]', caseSensitive: false);

/// Code that picks between two messages on a number that is not a count of
/// things, with the reason it stays. The list only shrinks.
const _codeChoices = <String, String>{
  'lib/features/workspace/presentation/widgets/bi_export_sheet.dart':
      'a refresh happened or not (reads > 1), not a count of things',
  'lib/features/money/presentation/invoice_reminder_letter.dart':
      'reminder level 1 is the friendly letter: a position, not a count',
  'lib/features/money/presentation/report_defaults.dart':
      'reminder level 1 is the friendly letter: a position, not a count',
  'lib/features/money/presentation/widgets/expense_schedule_sheet.dart':
      'every 1 is the word daily / weekly / monthly / yearly; the plural of '
      'the others lives in the scheduleEvery… messages',
  'lib/features/money/presentation/widgets/setup_reminders_step.dart':
      'reminder level 1 has its own sentence: a position, not a count',
  'lib/features/events/presentation/screens/events_screen.dart':
      'a collapsed row shows the times mark from 2 on: a multiplier, no noun',
};

typedef Arbs = Map<String, Map<String, dynamic>>;

Set<String> _numberPlaceholders(Map<dynamic, dynamic> meta) => {
  for (final MapEntry(:key, :value)
      in ((meta['placeholders'] as Map<dynamic, dynamic>?) ?? {}).entries)
    if (value is Map && (value['type'] == 'int' || value['type'] == 'num'))
      '$key',
};

/// Every finding, as `key placeholder language: what`.
List<String> plurals(Arbs arbs) {
  final en = arbs['en']!;
  final out = <String>[];
  for (final MapEntry(:key, :value) in en.entries) {
    if (key.startsWith('@') || value is! String) continue;
    final meta = (en['@$key'] as Map?) ?? const {};
    final description = '${meta['description']}';
    final numbers = _numberPlaceholders(meta);
    final marker = _marker.firstMatch(description);
    final exempt = <String>{
      if (marker != null)
        for (final n in marker.group(1)!.split(','))
          if (n.trim().isNotEmpty) n.trim(),
    };
    if (marker != null && exempt.isEmpty) {
      out.add('$key -: the exemption names no placeholder');
    }
    for (final n in exempt) {
      if (!numbers.contains(n)) {
        out.add(
          '$key $n: exempted but not a number placeholder of the message',
        );
      }
    }
    for (final lang in _languages) {
      final text = arbs[lang]![key];
      if (text is! String) continue;
      final nodes = parseIcu(text);
      final bare = bareArgs(nodes);
      final plural = pluralArgs(nodes);
      for (final n in numbers) {
        if (exempt.contains(n)) {
          if (plural.contains(n)) {
            out.add('$key $n $lang: exempted but it has a plural');
          }
          continue;
        }
        if (bare.contains(n)) {
          out.add('$key $n $lang: a bare count (outside a plural of its own)');
        } else if (!plural.contains(n) && allArgs(nodes).contains(n)) {
          out.add('$key $n $lang: no plural');
        } else if (!plural.contains(n)) {
          out.add('$key $n $lang: the placeholder is missing');
        }
      }
      for (final c in choicesOf(nodes).where((c) => c.kind == 'plural')) {
        final selectors = [for (final k in c.cases) k.$1];
        for (final s in selectors) {
          if (!allowedPluralSelectors.contains(s)) {
            out.add(
              '$key ${c.name} $lang: plural case "$s" (use one / other, =0)',
            );
          }
        }
        if (!selectors.contains('other') || !selectors.contains('one')) {
          out.add('$key ${c.name} $lang: a plural needs `one` and `other`');
        }
        if (oneCoversZero.contains(lang) && !selectors.contains('=0')) {
          final one = c.cases.where((k) => k.$1 == 'one');
          for (final k in one) {
            final reads =
                allArgs(k.$2).contains(c.name) ||
                k.$2.any((n) => n is IcuText && n.text.contains('#'));
            if (!reads) {
              out.add(
                '$key ${c.name} $lang: `one` covers 0 here but its form does '
                'not carry the number',
              );
            }
          }
        }
      }
      if (text.contains('(s)')) {
        out.add('$key - $lang: "(s)" instead of a plural');
      }
    }
  }
  return out;
}

Arbs _read() => {
  for (final l in _languages)
    l: jsonDecode(
      File('lib/l10n/app_$l.arb').readAsStringSync(),
    ) as Map<String, dynamic>,
};

Set<String> _baseline() => {
  for (final l in File('docs/design/PLURAL_BASELINE.txt').readAsLinesSync())
    if (l.trim().isNotEmpty && !l.startsWith('#')) l.trim(),
};

/// `key placeholder language` of a finding, the baseline's line.
String _line(String finding) => finding.split(':').first.trim();

/// A one-message planted catalogue in each language.
Arbs _planted(
  String key,
  Map<String, String> texts, {
  String description = 'planted',
  List<String> numbers = const ['n'],
}) => {
  for (final l in _languages)
    l: {
      key: texts[l] ?? texts['en']!,
      if (l == 'en')
        '@$key': {
          'description': description,
          'placeholders': {
            for (final n in numbers) n: {'type': 'int'},
          },
        },
    },
};

void main() {
  test('every count of every language is in a plural of its own (#3743)', () {
    final fresh = {for (final f in plurals(_read())) f}
        .where((f) => !_baseline().contains(_line(f)));
    expect(
      fresh,
      isEmpty,
      reason:
          'A count in a sentence is an ICU plural in all five languages '
          '({n, plural, one{…} other{…}}). A number that is not a count is '
          "named in the message's description: [not a count: n].\n"
          '${fresh.join('\n')}',
    );
  });

  test('the baseline only shrinks: a fixed message leaves it', () {
    final found = plurals(_read()).map(_line).toSet();
    final stale = _baseline().difference(found);
    expect(
      stale,
      isEmpty,
      reason:
          'These are right now (or gone): delete their lines from '
          'docs/design/PLURAL_BASELINE.txt.\n${stale.join('\n')}',
    );
  });

  test('code does not choose between two messages on a count', () {
    final choice = RegExp(
      r'(?:==|!=|<=|>=|<|>)\s*[12]\s*\?\s*\(?\s*\w*(?:l10n|loc|words)\w*\.\w+',
    );
    final found = <String>[];
    final listed = <String>{};
    for (final f in handWrittenDartFiles('lib')) {
      final path = f.path.replaceAll(r'\', '/');
      final text = File(f.path).readAsStringSync();
      for (final m in choice.allMatches(text)) {
        if (_codeChoices.containsKey(path)) {
          listed.add(path);
          continue;
        }
        final line = text.substring(0, m.start).split('\n').length;
        found.add('$path:$line');
      }
    }
    expect(
      _codeChoices.keys.toSet().difference(listed),
      isEmpty,
      reason: 'these no longer choose on a number: drop them from _codeChoices',
    );
    expect(
      found,
      isEmpty,
      reason:
          'English-only plural logic: give the message a plural in the ARB '
          'files and pass the number (#3743).\n${found.join('\n')}',
    );
  });

  group('the lint bites (planted catalogues)', () {
    test('a clean message is silent', () {
      final clean = _planted('x', {
        'en': '{n, plural, one{{n} day} other{{n} days}}',
        'fr': '{n, plural, one{{n} jour} other{{n} jours}}',
      });
      expect(plurals(clean), isEmpty);
    });

    test('one pluralised and one bare count in the same message', () {
      final mixed = _planted(
        'x',
        {
          'en': '{n, plural, one{one booking} other{{n} bookings}} for {days} days',
        },
        numbers: ['n', 'days'],
      );
      expect(
        plurals(mixed).where((f) => f.startsWith('x days en')),
        isNotEmpty,
      );
    });

    test('a translation whose plural was dropped', () {
      final dropped = _planted('x', {
        'en': '{n, plural, one{{n} day} other{{n} days}}',
        'de': '{n} Tage',
      });
      expect(plurals(dropped), [
        'x n de: a bare count (outside a plural of its own)',
      ]);
    });

    test('an exemption that names no placeholder', () {
      final bare = _planted('x', {
        'en': 'Column {n}',
      }, description: 'a column number [not a count: ]');
      expect(plurals(bare), isNotEmpty);
      final legacy = _planted('x', {
        'en': 'Column {n}',
      }, description: 'The number is not a count: it is a column number.');
      expect(plurals(legacy), isNotEmpty);
      final named = _planted('x', {
        'en': 'Column {n}',
      }, description: 'a column number [not a count: n]');
      expect(plurals(named), isEmpty);
    });

    test('an exemption does not hide the other count of the message', () {
      final one = _planted(
        'x',
        {'en': 'Line {line}: {n} errors'},
        description: 'a line [not a count: line]',
        numbers: ['line', 'n'],
      );
      expect(plurals(one).where((f) => f.startsWith('x n ')), isNotEmpty);
    });

    test('the case set: =1 is refused; French one carries its number', () {
      final eq1 = _planted('x', {
        'en': '{n, plural, =1{one day} other{{n} days}}',
      });
      expect(plurals(eq1).where((f) => f.contains('"=1"')), isNotEmpty);
      final fr = _planted('x', {
        'en': '{n, plural, one{one day} other{{n} days}}',
        'fr': '{n, plural, one{un jour} other{{n} jours}}',
      });
      expect(
        plurals(fr)
            .where((f) => f.contains('x n fr') && f.contains('covers 0')),
        isNotEmpty,
      );
      final fr0 = _planted('x', {
        'en': '{n, plural, one{one day} other{{n} days}}',
        'fr': '{n, plural, =0{aucun jour} one{un jour} other{{n} jours}}',
      });
      expect(plurals(fr0).where((f) => f.contains('covers 0')), isEmpty);
    });

    test('"(s)" is refused', () {
      final s = _planted('x', {
        'en': '{n, plural, one{{n} file(s)} other{{n} file(s)}}',
      });
      expect(plurals(s).where((f) => f.contains('"(s)"')), isNotEmpty);
    });
  });
}
