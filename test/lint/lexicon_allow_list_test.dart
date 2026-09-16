// SPDX-License-Identifier: 0BSD
//
// #1277 — the app and the server agree on which words a workspace may
// rename, or the feature is a trap.
//
// `lexicon_allowed_keys()` (0223) is the authority: the write RPC
// refuses any key it does not return. `lexiconAllowList` is what the
// editor browses and what `lexiconText` call sites are keyed on. If they
// drift, one of two things happens, and neither is visible without this
// test:
//
//   * a key only the DART side knows — the editor offers a word, the
//     owner renames it, and the server refuses the write;
//   * a key only the SERVER knows — the owner can never reach it, and a
//     term that was meant to be renameable silently is not.
//
// Both are silent because nothing else compares them: the migration is
// SQL and the allow-list is Dart.
import 'dart:io';

import 'package:deskilo/core/l10n/lexicon.dart';
import 'package:deskilo/core/l10n/lexicon_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

/// The keys `lexicon_allowed_keys()` returns, from the LATEST migration
/// that defines it — the same approach `configuration_classification_test`
/// uses for `deployable_entities()`. Reading the newest definition
/// matters: an earlier one would pin a set nobody serves.
Set<String> _serverKeys() {
  final defining = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) =>
          f.path.endsWith('.sql') &&
          f.readAsStringSync().contains('function public.lexicon_allowed_keys'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  expect(defining, isNotEmpty,
      reason: 'no migration defines lexicon_allowed_keys() — the allow-list '
          'has no server side, so nothing enforces it');
  return RegExp(r"\('([A-Za-z]+)','\{\}'::text\[\]\)")
      .allMatches(defining.last.readAsStringSync())
      .map((m) => m.group(1)!)
      .toSet();
}

/// Every key the English ARB defines, so the allow-list cannot name one
/// that does not exist.
Set<String> _arbKeys() {
  final source = File('lib/l10n/app_en.arb').readAsStringSync();
  return RegExp(r'"([A-Za-z][A-Za-z0-9]*)"\s*:')
      .allMatches(source)
      .map((m) => m.group(1)!)
      .where((k) => !k.startsWith('@'))
      .toSet();
}

void main() {
  test('the Dart allow-list is exactly what the server allows', () {
    final server = _serverKeys();
    final dart = lexiconAllowList.keys.toSet();

    expect(server, isNotEmpty,
        reason: 'the migration parsed to no keys at all — its array shape '
            'changed and this test is now measuring its own parser');

    expect(dart.difference(server), isEmpty,
        reason: 'these keys are in lexiconAllowList and NOT in '
            'lexicon_allowed_keys(): the editor would offer a word the '
            'server refuses to write.\n  '
            '${dart.difference(server).join('\n  ')}');

    expect(server.difference(dart), isEmpty,
        reason: 'these keys are allowed by the server and unknown to the '
            'app: a term meant to be renameable that nothing renders.\n  '
            '${server.difference(dart).join('\n  ')}');
  });

  test('every allow-listed key is a real ARB key', () {
    final arb = _arbKeys();
    final missing = lexiconAllowList.keys.where((k) => !arb.contains(k)).toList()
      ..sort();
    expect(missing, isEmpty,
        reason: 'these allow-listed terms have no key in app_en.arb, so '
            'their fallback could not resolve:\n  ${missing.join('\n  ')}');
  });

  test('every allow-listed key is actually rendered somewhere', () {
    // The rule #1277 S1 learned the hard way: `levelReserveTitle` was
    // allow-listed while no widget read it, so an owner could have
    // renamed a word that changes nothing on screen. A term is only
    // renameable if something renders it.
    final lib = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
        .where((f) => !f.path.startsWith('lib/l10n/'))
        .map((f) => f.readAsStringSync())
        .join('\n');

    final unrendered = lexiconAllowList.keys
        .where((k) => !lib.contains(k))
        .toList()
      ..sort();
    expect(unrendered, isEmpty,
        reason: 'these allow-listed terms are read by nothing in lib/, so '
            'renaming one would change nothing a member can see:\n  '
            '${unrendered.join('\n  ')}');
  });

  test('every allow-listed key has a product default the editor can show', () {
    // #1277 S3 — the editor shows the product's own word beside the
    // override, so an owner sees what they are replacing. `lexiconDefault`
    // falls back to returning the KEY when it has no arm, which would put
    // `legendFree` on screen where "Free" belongs. Nothing else would
    // catch that: it renders, it just renders nonsense.
    final unresolved = lexiconAllowList.keys
        .where((k) => lexiconDefault(null, k) == k)
        .toList()
      ..sort();
    expect(unresolved, isEmpty,
        reason: 'these allow-listed terms have no arm in lexiconDefault, so '
            'the wording editor would show the key instead of the word:\n  '
            '${unresolved.join('\n  ')}');
  });

  test('a term declaring placeholders names them exactly', () {
    // Tokenless today, on both sides. The rule exists before the first
    // key that needs one; the server compares the same way (0223).
    final arb = File('lib/l10n/app_en.arb').readAsStringSync();
    for (final entry in lexiconAllowList.entries) {
      final value = RegExp('"${entry.key}"\\s*:\\s*"([^"]*)"').firstMatch(arb);
      if (value == null) continue;
      final tokens = RegExp(r'\{(\w+)\}')
          .allMatches(value.group(1)!)
          .map((m) => m.group(1)!)
          .toSet();
      expect(tokens, entry.value.placeholders.toSet(),
          reason: '${entry.key}: the ARB string carries $tokens and the '
              'allow-list declares ${entry.value.placeholders}. The server '
              'refuses an override whose token set differs, so these must '
              'agree or the owner cannot save.');
    }
  });
}
