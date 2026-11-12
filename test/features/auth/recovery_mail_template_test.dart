// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3812 (part of #3657, i18n I11d) -- the recovery e-mail reads in the
// account's language. Auth renders it from the template with the account's
// metadata, where the server writes the language (0743, pgTAP 407). This
// holds the template's side: a branch per language, each carrying the
// one-time code exactly once, the installation's default (English) when no
// language is written, and a subject in no language at all. Rendering the
// real message per language is the operator's check (docs/guides/OPERATIONS.md,
// "The recovery e-mail's language").
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _template = 'supabase/templates/auth/recovery.html';
const _languages = ['fr', 'de', 'es', 'it'];

/// The branches of [template]: the text after each `if`/`else if` on the
/// language, and after the final `else`, keyed by the language ('' for the
/// default).
Map<String, String> branchesOf(String template) {
  final marks = RegExp(
    r'\{\{\s*(?:else\s+)?if\s+eq\s+\$l\s+"([a-z]{2})"\s*\}\}|\{\{\s*else\s*\}\}|\{\{\s*end\s*\}\}',
  ).allMatches(template).toList();
  final branches = <String, String>{};
  for (var i = 0; i + 1 < marks.length; i++) {
    final key = marks[i].group(1) ?? '';
    branches[key] = template.substring(marks[i].end, marks[i + 1].start);
  }
  return branches;
}

void main() {
  final template = File(_template).readAsStringSync();
  final branches = branchesOf(template);

  test('a branch for each language, and the default', () {
    expect(branches.keys.toSet(), {..._languages, ''});
  });

  test('every branch carries the one-time code exactly once', () {
    for (final MapEntry(key: language, value: text) in branches.entries) {
      expect(
        '{{ .Token }}'.allMatches(text).length,
        1,
        reason: language.isEmpty ? 'the default' : language,
      );
    }
  });

  test('the default is the installation\'s language, English', () {
    expect(branches[''], contains('Reset your password'));
    for (final language in _languages) {
      expect(
        branches[language],
        isNot(contains('Reset your password')),
        reason: language,
      );
    }
  });

  test('the language is read as text, so a missing one never fails', () {
    expect(template, contains(r'{{ $l := printf "%v" .Data.locale }}'));
  });

  test('the subject names the product only', () {
    final config = File('supabase/config.toml').readAsStringSync();
    final recovery = config.substring(
      config.indexOf('[auth.email.template.recovery]'),
    );
    final subject = RegExp(
      r'^subject = "([^"]*)"',
      multiLine: true,
    ).firstMatch(recovery);
    expect(subject?.group(1), 'DesKilo');
  });
}
