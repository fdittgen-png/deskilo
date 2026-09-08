// SPDX-License-Identifier: 0BSD
//
// #1016 — the anchor is one identity for the help symbol, the guide
// heading and the screenshot. This is what keeps the three in step.
import 'dart:io';

import 'package:deskilo/core/help/help_anchors.dart';
import 'package:flutter_test/flutter_test.dart';

const _guides = {
  'en': 'docs/wiki/User-Guide.md',
  'fr': 'docs/wiki/Guide-utilisateur.md',
  'de': 'docs/wiki/Benutzerhandbuch.md',
  'es': 'docs/wiki/Guia-de-usuario.md',
  'it': 'docs/wiki/Guida-utente.md',
};

final _comment =
    RegExp(r'<!--\s*anchor:\s*([a-z][a-z0-9]*(?:\.[a-z0-9-]+)+)\s*-->');

/// anchor -> the heading it names, per guide. An anchor that names no
/// heading is reported as an empty string, so the assertion lives in a
/// test rather than at load time.
Map<String, String> _anchorsOf(String path) {
  final lines = File(path).readAsLinesSync();
  final found = <String, String>{};
  for (var i = 0; i < lines.length - 1; i++) {
    final match = _comment.firstMatch(lines[i]);
    if (match == null) continue;
    var j = i + 1;
    while (j < lines.length && lines[j].trim().isEmpty) {
      j++;
    }
    final heading = j < lines.length && lines[j].startsWith('#') ? lines[j] : '';
    found[match.group(1)!] = heading;
  }
  return found;
}

void main() {
  final perGuide = {
    for (final e in _guides.entries) e.key: _anchorsOf(e.value),
  };

  test('an anchor comment sits on the line above the heading it names', () {
    for (final entry in perGuide.entries) {
      for (final anchor in entry.value.entries) {
        expect(anchor.value, isNotEmpty,
            reason: '${anchor.key} in ${_guides[entry.key]} is followed by no '
                'heading — an anchor names a heading, nothing else');
      }
    }
  });

  test('every anchor the app points at exists in all five guides', () {
    for (final anchor in HelpAnchor.all) {
      for (final entry in perGuide.entries) {
        expect(entry.value.keys, contains(anchor),
            reason: '$anchor is missing from ${_guides[entry.key]} — a help '
                'symbol would open the top of the guide in ${entry.key}');
      }
    }
  });

  test('an anchor names one heading per guide, never two', () {
    for (final entry in _guides.entries) {
      final seen = <String>{};
      for (final line in File(entry.value).readAsLinesSync()) {
        final match = _comment.firstMatch(line);
        if (match == null) continue;
        expect(seen.add(match.group(1)!), isTrue,
            reason: '${match.group(1)} appears twice in ${entry.value}');
      }
    }
  });

  test('every declared anchor is in HelpAnchor.all — the lint sees them all',
      () {
    final source = File('lib/core/help/help_anchors.dart').readAsStringSync();
    final declared = RegExp(r"static const \w+ = '([^']+)';")
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toList();
    expect(declared, isNotEmpty);
    expect(HelpAnchor.all, containsAll(declared),
        reason: 'a constant outside `all` is invisible to this lint');
    expect(HelpAnchor.all.length, declared.length);
  });

  test('an anchor is lower case, dotted, and says which guide it belongs to',
      () {
    final shape = RegExp(r'^(user|admin|config|env)(\.[a-z0-9-]+){2,}$');
    for (final anchor in HelpAnchor.all) {
      expect(shape.hasMatch(anchor), isTrue, reason: anchor);
    }
  });

  test('the guides are structurally parallel: the same anchors, everywhere',
      () {
    final english = perGuide['en']!.keys.toSet();
    for (final entry in perGuide.entries) {
      expect(entry.value.keys.toSet(), english,
          reason: '${_guides[entry.key]} anchors differently from the English '
              'guide — the five guides must stay parallel');
    }
  });

  test('the image an anchor promises is named after it', () {
    expect(HelpAnchor.imageFor('user.money.vat.rates'),
        'user-money-vat-rates.jpg');
  });
}
