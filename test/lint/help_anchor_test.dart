// SPDX-License-Identifier: 0BSD
//
// #1016/#1018 — the anchor is one identity for the help symbol, the guide
// heading and the screenshot. This is what keeps the three in step, and
// what stops a symbol pointing into a guide that is not translated yet.
import 'dart:io';

import 'package:deskilo/core/help/help_anchors.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guide family -> the five files that carry it. A family may be
/// mid-translation: the files that exist must agree, and a help symbol
/// may only point into a family that is complete.
const _families = <String, Map<String, String>>{
  'user': {
    'en': 'docs/wiki/User-Guide.md',
    'fr': 'docs/wiki/Guide-utilisateur.md',
    'de': 'docs/wiki/Benutzerhandbuch.md',
    'es': 'docs/wiki/Guia-de-usuario.md',
    'it': 'docs/wiki/Guida-utente.md',
  },
  'config': {
    'en': 'docs/wiki/Admin-Configuration-Guide.md',
    'fr': 'docs/wiki/Admin-Configuration-Guide.fr.md',
    'de': 'docs/wiki/Admin-Configuration-Guide.de.md',
    'es': 'docs/wiki/Admin-Configuration-Guide.es.md',
    'it': 'docs/wiki/Admin-Configuration-Guide.it.md',
  },
  'admin': {
    'en': 'docs/wiki/Admin-Technical-Guide.md',
    'fr': 'docs/wiki/Admin-Technical-Guide.fr.md',
    'de': 'docs/wiki/Admin-Technical-Guide.de.md',
    'es': 'docs/wiki/Admin-Technical-Guide.es.md',
    'it': 'docs/wiki/Admin-Technical-Guide.it.md',
  },
  'env': {
    'en': 'docs/wiki/Environments-Guide.md',
    'fr': 'docs/wiki/Environments-Guide.fr.md',
    'de': 'docs/wiki/Environments-Guide.de.md',
    'es': 'docs/wiki/Environments-Guide.es.md',
    'it': 'docs/wiki/Environments-Guide.it.md',
  },
};

final _comment =
    RegExp(r'<!--\s*anchor:\s*([a-z][a-z0-9]*(?:\.[a-z0-9-]+)+)\s*-->');

/// anchor -> the heading it names ('' when it names none, so the
/// assertion can live in a test rather than at load time).
Map<String, String> _anchorsOf(String path) {
  if (!File(path).existsSync()) return const {};
  final lines = File(path).readAsLinesSync();
  final found = <String, String>{};
  for (var i = 0; i < lines.length - 1; i++) {
    final match = _comment.firstMatch(lines[i]);
    if (match == null) continue;
    var j = i + 1;
    while (j < lines.length && lines[j].trim().isEmpty) {
      j++;
    }
    found[match.group(1)!] =
        j < lines.length && lines[j].startsWith('#') ? lines[j] : '';
  }
  return found;
}

void main() {
  final read = {
    for (final family in _families.entries)
      family.key: {
        for (final file in family.value.entries)
          if (File(file.value).existsSync()) file.key: _anchorsOf(file.value),
      },
  };

  test('an anchor comment sits on the line above the heading it names', () {
    for (final family in read.entries) {
      for (final lang in family.value.entries) {
        for (final anchor in lang.value.entries) {
          expect(anchor.value, isNotEmpty,
              reason: '${anchor.key} in ${_families[family.key]![lang.key]} '
                  'is followed by no heading');
        }
      }
    }
  });

  test('an anchor belongs to the guide its first segment names', () {
    for (final family in read.entries) {
      for (final lang in family.value.entries) {
        for (final anchor in lang.value.keys) {
          expect(anchor.split('.').first, family.key,
              reason: '$anchor lives in the ${family.key} guide but claims '
                  'to belong to another');
        }
      }
    }
  });

  test('a translation that exists is parallel to the English guide', () {
    for (final family in read.entries) {
      final english = family.value['en']?.keys.toSet();
      if (english == null) continue;
      for (final lang in family.value.entries) {
        if (lang.key == 'en') continue;
        expect(lang.value.keys.toSet(), english,
            reason: '${_families[family.key]![lang.key]} anchors differently '
                'from the English guide — the guides stay parallel');
      }
    }
  });

  test('a help symbol only points into a guide that all five languages have',
      () {
    for (final anchor in HelpAnchor.all) {
      final family = anchor.split('.').first;
      expect(_families.keys, contains(family), reason: anchor);
      for (final lang in _families[family]!.keys) {
        expect(read[family]![lang]?.keys, contains(anchor),
            reason: '$anchor is missing from '
                '${_families[family]![lang]} — a symbol would open the top of '
                'the guide in $lang');
      }
    }
  });

  test('an anchor names one heading per guide, never two', () {
    for (final family in _families.values) {
      for (final path in family.values) {
        if (!File(path).existsSync()) continue;
        final seen = <String>{};
        for (final line in File(path).readAsLinesSync()) {
          final match = _comment.firstMatch(line);
          if (match == null) continue;
          expect(seen.add(match.group(1)!), isTrue,
              reason: '${match.group(1)} appears twice in $path');
        }
      }
    }
  });

  test('every declared anchor is in HelpAnchor.all — the lint sees them all',
      () {
    final source = File('lib/core/help/help_anchors.dart').readAsStringSync();
    // #1019 — `\s*` after the `=`: a long anchor wraps onto the next
    // line, and a wrapped declaration is still a declaration. Matching
    // only the one-line form silently under-counted, so a constant
    // missing from [HelpAnchor.all] could hide behind the wrap.
    final declared = RegExp(r"static const \w+ =\s*'([^']+)';")
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toList();
    expect(declared, isNotEmpty);
    expect(HelpAnchor.all, containsAll(declared));
    expect(HelpAnchor.all.length, declared.length);
  });

  test('an anchor is lower case, dotted, and says which guide it belongs to',
      () {
    final shape = RegExp(r'^(user|admin|config|env)(\.[a-z0-9-]+){2,}$');
    for (final anchor in HelpAnchor.all) {
      expect(shape.hasMatch(anchor), isTrue, reason: anchor);
    }
  });

  test('the image an anchor promises is named after it', () {
    expect(HelpAnchor.imageFor('user.money.vat.rates'),
        'user-money-vat-rates.jpg');
  });
}
