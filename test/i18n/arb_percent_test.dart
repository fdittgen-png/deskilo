// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3819 — a rate inside a message reads in the locale's own percent form
// (`20 %` in German, `20%` in English): the message never builds it with a
// literal sign beside a number placeholder. The rate goes in as a String that
// `AppFormat.ratePercent` / `fractionPercent` formatted, or the call site
// prints the rate itself. A number placeholder is one declared `int`, `num`
// or `double` in the English metadata; the check reads every language.
//
// #4429 -- a TEXT placeholder beside a literal sign is the same defect one
// step removed: the call site hands in a bare number as text (`'75'`) and the
// message adds the sign. A formatted rate already carries its own sign. The
// keys still built that way are listed below with the call site to sweep; the
// list only shrinks.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _languages = ['en', 'de', 'fr', 'es', 'it'];

/// A literal percent sign directly beside a placeholder (or the `#` of an
/// ICU plural), either side, with at most one space between.
final _beside = RegExp(
  r'(?:\{(\w+)\}|#)[\s  ]?%|%[\s  ]?(?:\{(\w+)\}|#)',
);

/// Every finding, as `key language: the text`.
List<String> percentBesideNumber(Map<String, Map<String, dynamic>> arbs) {
  final en = arbs['en']!;
  final out = <String>[];
  for (final MapEntry(:key, :value) in en.entries) {
    if (key.startsWith('@') || value is! String) continue;
    final meta = (en['@$key'] as Map?) ?? const {};
    final numbers = {
      for (final MapEntry(:key, :value)
          in ((meta['placeholders'] as Map?) ?? {}).entries)
        if (value is Map &&
            const {'int', 'num', 'double'}.contains(value['type']))
          '$key',
    };
    if (numbers.isEmpty) continue;
    for (final lang in _languages) {
      final text = arbs[lang]![key];
      if (text is! String) continue;
      for (final m in _beside.allMatches(text)) {
        final name = m.group(1) ?? m.group(2);
        if (name == null || numbers.contains(name)) {
          out.add('$key $lang: ${m.group(0)}');
        }
      }
    }
  }
  return out;
}

Map<String, Map<String, dynamic>> _planted(String text) => {
  for (final l in _languages)
    l: {
      'k': text,
      if (l == 'en')
        '@k': {
          'placeholders': {
            'n': {'type': 'int'},
            's': {'type': 'String'},
          },
        },
    },
};

void main() {
  group('the check sees what it names, and only that', () {
    test('a literal sign beside a number placeholder is found', () {
      expect(percentBesideNumber(_planted('{n} %')), hasLength(5));
      expect(percentBesideNumber(_planted('{n}%')), hasLength(5));
      expect(percentBesideNumber(_planted('% {n}')), hasLength(5));
      expect(
        percentBesideNumber(_planted('{n, plural, other{# %}}')),
        hasLength(5),
      );
    });

    test('a formatted rate, a sign beside a word and no sign are not', () {
      expect(percentBesideNumber(_planted('{s}')), isEmpty);
      expect(percentBesideNumber(_planted('Rate: {s} of {n} days')), isEmpty);
      expect(percentBesideNumber(_planted('100 % done, {n} left')), isEmpty);
    });

    test('a text placeholder beside a literal sign is found (#4429)', () {
      expect(percentBesideText(_planted('{s} %')), hasLength(5));
      expect(percentBesideText(_planted('{s}%')), hasLength(5));
      expect(percentBesideText(_planted('{s}')), isEmpty);
      expect(percentBesideText(_planted('{n} %')), isEmpty, reason: 'the number check reports that one');
    });
  });

  test('no message puts a literal sign beside a number placeholder', () {
    final arbs = {
      for (final l in _languages)
        l:
            jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync())
                as Map<String, dynamic>,
    };
    expect(percentBesideNumber(arbs), isEmpty);
  });

  test('a text placeholder beside a literal sign is only one of the keys left to sweep (#4429)', () {
    final arbs = {
      for (final l in _languages)
        l:
            jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync())
                as Map<String, dynamic>,
    };
    final keys = {for (final f in percentBesideText(arbs)) f.split(' ').first};
    expect(keys.difference(_textPercentLeft), isEmpty,
        reason: 'pass AppFormat.ratePercent(rate) and drop the sign from the message');
    expect(_textPercentLeft.difference(keys), isEmpty,
        reason: 'a key that was swept leaves the list');
  });
}

/// The keys that still add a literal sign to a bare number handed in as text,
/// each with the call site that formats it (#4429). The list only shrinks.
const _textPercentLeft = {
  'datevProblemAutomatic', // gobd_procedure_document.dart: a document, rate.format(percent)
  'datevProblemTaxKey', // gobd_procedure_document.dart: a document, rate.format(percent)
  'itemGroupMarginValue', // item_group_text.dart: percentOfMarginBps
  'mcpConfirmNewShare', // mcp_confirmation_screen.dart: the share the assistant asks for
  'mcpConfirmShareFrom', // mcp_confirmation_screen.dart: the share the assistant asks for
  'memberPlanShare', // member_contact_card.dart: subscriptionPct
  'setupGrowVatPreviewRate', // setup_vat_step.dart: _rate
  'setupGrowVatRate', // setup_vat_step.dart: _rate
  'tillDayRateLine', // till_drawer/day_report_view.dart: the till's day report
};

/// Every literal sign beside a TEXT placeholder, as `key language: the text`.
List<String> percentBesideText(Map<String, Map<String, dynamic>> arbs) {
  final en = arbs['en']!;
  final out = <String>[];
  for (final MapEntry(:key, :value) in en.entries) {
    if (key.startsWith('@') || value is! String) continue;
    final meta = (en['@$key'] as Map?) ?? const {};
    final texts = {
      for (final MapEntry(:key, :value)
          in ((meta['placeholders'] as Map?) ?? {}).entries)
        if (value is! Map || value['type'] == null || value['type'] == 'String')
          '$key',
    };
    if (texts.isEmpty) continue;
    for (final lang in _languages) {
      final text = arbs[lang]![key];
      if (text is! String) continue;
      for (final m in _beside.allMatches(text)) {
        final name = m.group(1) ?? m.group(2);
        if (name != null && texts.contains(name)) {
          out.add('$key $lang: ${m.group(0)}');
        }
      }
    }
  }
  return out;
}
