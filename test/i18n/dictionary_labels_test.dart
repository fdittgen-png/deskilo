// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3485 -- a dictionary label is one ARB key per case, mapped in
// lib/l10n/dictionary_labels.dart. This pins the mapping to the catalogue:
// every case the extension lists has its key in every locale, every key of a
// label family is listed, and an unlisted word is shown as written.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/dictionary_labels.dart';
import 'package:flutter_test/flutter_test.dart';

final _method = RegExp(r'String (\w+)\(([^)]*)\) => switch');
final _arm = RegExp(r"^\s*'((?:[^'\\]|\\.)*)' => (\w+)", multiLine: true);

void main() {
  final source = File('lib/l10n/dictionary_labels.dart').readAsStringSync();
  final arbKeys = (jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>)
      .keys
      .where((k) => !k.startsWith('@'))
      .toSet();

  // method name -> the ARB key behind each case
  final families = <String, Map<String, String>>{};
  for (final m in _method.allMatches(source)) {
    final start = m.end;
    final next = _method.firstMatch(source.substring(start));
    final end = next == null ? source.length : start + next.start;
    families[m.group(1)!] = {
      for (final arm in _arm.allMatches(source.substring(start, end)))
        arm.group(1)!: arm.group(2)!,
    };
  }

  test('every label family lists every key of its prefix, and only those', () {
    expect(families, isNotEmpty);
    for (final e in families.entries) {
      final listed = e.value.values.toSet();
      final prefixed = {
        for (final k in arbKeys)
          if (k.startsWith(e.key) &&
              k.length > e.key.length &&
              RegExp('[A-Z0-9]').hasMatch(k[e.key.length]))
            k,
      };
      expect(listed.difference(arbKeys), isEmpty, reason: '${e.key}: a case has no key');
      expect(
        prefixed.difference(listed),
        isEmpty,
        reason: '${e.key}: a key is not in the mapping (add its arm)',
      );
    }
  });

  test('an unlisted word is shown as written, a listed one is worded', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final words = lookupAppLocalizations(locale);
      expect(words.exportColumnName('not_a_column'), 'not_a_column');
      expect(words.setupStepTitle('not_a_step'), 'not_a_step');
      expect(words.dataReportPart('members'), isNot('members'),
          reason: locale.languageCode);
    }
  });
}
