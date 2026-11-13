// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3850 — the languages the app ships documents in are written twice: in
// the server's `document_language_supported` (the migration that last
// defines it) and in `documentLanguagesShipped`. They must name the same
// languages, and those must be the bundles the app ships.
import 'package:deskilo/core/locale/report_language.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  test('the server\'s shipped languages are the app\'s', () {
    final definers = [
      for (final f in sqlFiles('supabase/migrations'))
        if (f.readAsStringSync().contains(
          'function public.document_language_supported(',
        ))
          f,
    ];
    expect(definers, isNotEmpty);
    final sql = definers.last.readAsStringSync();
    final body = RegExp(
      r"document_language_supported\(p_language text\)[\s\S]*?in \(([^)]*)\)",
    ).firstMatch(sql);
    expect(
      body,
      isNotNull,
      reason: '${definers.last.path} lists its languages',
    );
    final server = {
      for (final m in RegExp(r"'([a-z]{2})'").allMatches(body!.group(1)!))
        m.group(1)!,
    };
    expect(server, documentLanguagesShipped);
    expect({
      for (final l in AppLocalizations.supportedLocales) l.languageCode,
    }, documentLanguagesShipped);
  });
}
