// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3555 — Me and Discover say "place" for where you go and "business" for
// who runs it. The app serves coworking spaces, studios, practices and
// salons side by side, so a string a person meets in Me or in Discover never
// calls either of them a "space" or a "workspace" (nor the same word in the
// other four languages).
//
// What is counted: every ARB key whose name is read under lib/features/me or
// the directory's presentation files, in each of the five languages. A key
// that says the word where it means the place or the business fails. A key
// that must keep it (the name of a business's own thing) says so in its
// English `@description` with a bracketed `[own-words: <reason>]`; the keys
// carrying that tag are counted and the count may only go down.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Workspace-admin screens that live beside Discover in the directory
/// feature: they are read by the business itself, in its own words.
const _adminScreens = <String, String>{
  'public_page_editor.dart': 'the business edits its own public page',
  'setup_public_page_step.dart': 'a step of the business owner\'s setup guide',
  'admin_visibility_tile.dart': 'an administrator\'s switch in the business',
  'member_employment_tile.dart': 'a business records who it employs',
};

/// The tagged keys left today. Lower it when one is reworded.
const _ownWordsKeys = 0;

/// The word, per language, that names a space or a workspace.
final _spaceWord = <String, RegExp>{
  'en': RegExp(r'\b(work)?spaces?\b', caseSensitive: false),
  'de': RegExp(r'space|bereich', caseSensitive: false),
  'fr': RegExp(r'\bespaces?\b', caseSensitive: false),
  'es': RegExp(r'\bespacios?\b', caseSensitive: false),
  'it': RegExp(r'\bspazi[o]?\b', caseSensitive: false),
};

final _ownWordsTag = RegExp(r'\[own-words: ([^\]]{12,})\]');

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Keys named in the sources of Me and Discover.
Set<String> _keysRead(Set<String> catalogue) {
  final files = <File>[
    ...handWrittenDartFiles('lib/features/me'),
    ...handWrittenDartFiles('lib/features/directory/presentation').where(
      (f) => !_adminScreens.keys.any(f.path.replaceAll(r'\', '/').endsWith),
    ),
  ];
  final word = RegExp(r'\b[a-z][A-Za-z0-9_]*\b');
  final read = <String>{};
  for (final f in files) {
    for (final m in word.allMatches(f.readAsStringSync())) {
      if (catalogue.contains(m.group(0))) read.add(m.group(0)!);
    }
  }
  return read;
}

/// The words a person reads: a bare `{placeholder}` is not one of them.
String _text(Object? value) =>
    ((value as String?) ?? '').replaceAll(RegExp(r'\{\w+\}'), '');

void main() {
  test('Me and Discover say place and business, not space or workspace', () {
    final arb = {for (final l in _spaceWord.keys) l: _arb(l)};
    final en = arb['en']!;
    final catalogue = en.keys.where((k) => !k.startsWith('@')).toSet();
    final read = _keysRead(catalogue);
    expect(read.length, greaterThan(200), reason: 'the scan lost its sources');

    final found = <String>[];
    final tagged = <String>[];
    for (final key in read.toList()..sort()) {
      final description =
          ((en['@$key'] as Map<String, dynamic>?)?['description'] as String?) ??
          '';
      final languages = [
        for (final l in _spaceWord.keys)
          if (_spaceWord[l]!.hasMatch(_text(arb[l]![key]))) l,
      ];
      if (languages.isEmpty) continue;
      if (_ownWordsTag.hasMatch(description)) {
        tagged.add(key);
      } else {
        found.add('$key (${languages.join(', ')})');
      }
    }

    expect(
      found,
      isEmpty,
      reason:
          'Me and Discover say "place" (where you go) and "business" (who '
          'runs it); "space" stays in a coworking business\'s own screens '
          '(#3555). Reword the value in the five fragments, or give Me its '
          'own key when an admin screen reads this one.',
    );
    expect(
      tagged.length,
      lessThanOrEqualTo(_ownWordsKeys),
      reason:
          'keys that keep the word with a stated [own-words: reason] may only '
          'shrink: $tagged',
    );
  });

  test('every screen kept out of the scan says why', () {
    for (final entry in _adminScreens.entries) {
      expect(
        File('lib/features/directory/presentation/${entry.key}')
            .existsSync(),
        isTrue,
        reason: '${entry.key} no longer exists: drop it from the exemptions',
      );
      expect(entry.value.length, greaterThan(10));
    }
  });
}
