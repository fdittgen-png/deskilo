// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3744 — the joined-sentence scan reads string EXPRESSIONS. Each case plants
// a source string, the way the scan sees real files.
import 'package:flutter_test/flutter_test.dart';

import 'sentence_joins.dart';

const _spaceOnly = {'sentencePair'};

String _fn(String body) => 'String f(dynamic l10n, int a, int b) {\n$body\n}\n';

void main() {
  group('a sentence joined from translated pieces is found', () {
    test('one literal with a translated read and a second value', () {
      expect(
        sentenceJoins(_fn(r"  return '${l10n.on} $a ${l10n.of} $b';")),
        hasLength(1),
      );
    });

    test('planted (a): adjacent literals on two lines', () {
      final hits = sentenceJoins(
        _fn(
          "  return '\${l10n.booked} '\n"
          "      '\$a';",
        ),
      );
      expect(hits, hasLength(1));
      expect(hits.single, startsWith('2: '));
    });

    test('planted (b): a sentence built with +', () {
      expect(
        sentenceJoins(_fn("  return l10n.booked + ' ' + a.toString();")),
        hasLength(1),
      );
    });

    test('planted (c): a translated text put in a local first', () {
      expect(
        sentenceJoins(
          _fn(
            '  final label = l10n.booked;\n'
            "  return '\$label \$a';",
          ),
        ),
        hasLength(1),
      );
    });
  });

  group('a space-only shared pattern is a join in another form', () {
    test('planted (d): sentencePair with a translated piece', () {
      expect(
        sentenceJoins(
          _fn('  return l10n.sentencePair(l10n.booked, a);'),
          spaceOnly: _spaceOnly,
        ),
        hasLength(1),
      );
    });

    test('sentencePair with a translated local', () {
      expect(
        sentenceJoins(
          _fn(
            '  final label = l10n.booked;\n'
            '  return l10n.sentencePair(label, a);',
          ),
          spaceOnly: _spaceOnly,
        ),
        hasLength(1),
      );
    });

    test('labelWithValue and titleDashDetail carry a separator', () {
      expect(
        sentenceJoins(_fn('  return l10n.labelWithValue(l10n.x, a);')),
        isEmpty,
      );
      expect(
        sentenceJoins(_fn('  return l10n.titleDashDetail(l10n.x, a);')),
        isEmpty,
      );
    });
  });

  group('independent pieces are allowed', () {
    test('the allowed separators', () {
      for (final sep in [' · ', ' | ', r'\n']) {
        expect(
          sentenceJoins(_fn("  return '\${l10n.x}$sep\$a';")),
          isEmpty,
          reason: 'separator "$sep"',
        );
      }
    });

    test('adjacent literals joined by an allowed separator', () {
      expect(
        sentenceJoins(_fn("  return '\${l10n.x} · '\n      '\$a';")),
        isEmpty,
      );
    });

    test('the name of the language is not a translated read (#3767)', () {
      expect(
        sentenceJoins(_fn("  return '\${l10n.localeName} \$a';")),
        isEmpty,
      );
      expect(
        sentenceJoins(_fn("  return '\${l10n.booked} \$a';")),
        hasLength(1),
      );
    });

    test('values without a translated read', () {
      expect(sentenceJoins(_fn("  return '\$a of \$b';")), isEmpty);
    });
  });

  group('the report-template exception is a real control tag', () {
    test('a template control tag between two pieces is accepted', () {
      expect(
        sentenceJoins(
          _fn("  return '\${l10n.x}{% if due != \"\" %}\$a{% endif %}';"),
        ),
        isEmpty,
      );
      expect(
        sentenceJoins(
          _fn("  return '\${l10n.x}{% elsif proforma %}\${l10n.y}';"),
        ),
        isEmpty,
      );
      expect(
        sentenceJoins(_fn("  return '\${l10n.x}{% endfor %}\$a';")),
        isEmpty,
      );
    });

    test('text that merely contains {% between two pieces is not', () {
      for (final between in ['{% ', ' {% x ', r'{%%}', '{% unknown %}']) {
        expect(
          sentenceJoins(_fn("  return '\${l10n.x}$between\${l10n.y}';")),
          hasLength(1),
          reason: 'between "$between"',
        );
      }
    });

    test('a line break ends the sentence; a space does not (#3768)', () {
      for (final between in [r'\n', r'\n---\n', r' {{ number }}\n> ', r'\n\n']) {
        expect(
          sentenceJoins(_fn("  return '\${l10n.x}$between\${l10n.y}';")),
          isEmpty,
          reason: 'between "$between"',
        );
      }
      expect(
        sentenceJoins(_fn(r"  return '${l10n.x}: ${l10n.y}';")),
        hasLength(1),
      );
      expect(
        sentenceJoins(_fn(r"  return '${l10n.x}${l10n.y}';")),
        hasLength(1),
      );
    });

    test('isIndependentJoin names the tags', () {
      expect(isIndependentJoin('{% if a %}'), isTrue);
      expect(isIndependentJoin('{%- endif -%}'), isTrue);
      expect(isIndependentJoin('{%'), isFalse);
      expect(isIndependentJoin(' {% '), isFalse);
      expect(isIndependentJoin(' '), isFalse);
    });
  });
}
