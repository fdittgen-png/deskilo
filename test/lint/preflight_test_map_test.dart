// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3715 -- the table of tests a changed path drags in (`tool/preflight/
// test_map.json`) stays true: every pattern matches a file, every listed test
// exists, and the three changes of 11 Nov list the tests that went red.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/preflight/affected_tests.dart';

void main() {
  final table = readTestMap(File('tool/preflight/test_map.json'));
  final tracked =
      (Process.runSync('git', ['ls-files']).stdout as String)
          .split('\n')
          .where((l) => l.isNotEmpty)
          .toList();

  test('every pattern of the table matches at least one file', () {
    final dead = [
      for (final row in table)
        for (final p in row.patterns)
          if (!tracked.any(patternRegExp(p).hasMatch)) p,
    ];
    expect(dead, isEmpty, reason: 'patterns that match nothing: $dead');
  });

  test('every test the table lists exists', () {
    final missing = [
      for (final row in table)
        for (final t in row.tests)
          if (FileSystemEntity.typeSync(t) == FileSystemEntityType.notFound) t,
    ];
    expect(missing, isEmpty, reason: 'listed tests that do not exist: $missing');
  });

  test('the check can fail: a planted pattern that matches nothing is found', () {
    final planted = patternRegExp('lib/does_not_exist_anywhere/**');
    expect(tracked.any(planted.hasMatch), isFalse);
    expect(tracked.any(patternRegExp('lib/app/routes/**').hasMatch), isTrue);
  });

  group('the changes of 11 Nov list the tests that went red', () {
    const sources = <String, String>{};
    List<String> list(List<String> changed) =>
        affectedTests(changed, table, sources);

    test('a new route', () {
      expect(
        list(['lib/app/routes/profile_routes.dart', 'lib/app/route_classes.dart']),
        containsAll([
          'test/app/route_outcomes_golden_test.dart',
          'test/features/task_recorder/coverage_manifest_test.dart',
          'test/lint/route_registry_test.dart',
        ]),
      );
    });

    test('#3751 a migration or a database test: the preview is named, with '
        'its command; a change elsewhere is not told to run it', () {
      for (final changed in const [
        'supabase/migrations/0718_apply_payment_to_invoices.sql',
        'supabase/tests/database/389_apply_payment_to_invoices.sql',
        'assets/instance/contract.txt',
      ]) {
        final notes = notesFor([changed], table);
        expect(notes, hasLength(1), reason: changed);
        expect(notes.single, contains('gh workflow run db-preview.yml --ref'));
      }
      expect(notesFor(['lib/app/router.dart', 'supabase/functions/x.ts'], table),
          isEmpty);
    });

    test('a workflow or a script: the tool tests', () {
      expect(list(['.github/workflows/quality.yml']), contains('test/tool/'));
      expect(list(['scripts/contract_check.sh']), contains('test/tool/'));
    });

    test('an ARB fragment', () {
      expect(list(['lib/l10n/_fragments/portal_en.arb']), contains('test/i18n/'));
    });

    test('a provider override in main: the Demo scope tests; importers by search',
        () {
      expect(
        list(['lib/main.dart']),
        contains('test/core/demo/demo_scope_test.dart'),
      );
      expect(
        affectedTests(
          ['lib/features/me/providers/me_providers.dart'],
          table,
          {
            'test/features/me/space_offers_test.dart':
                "import 'package:deskilo/features/me/providers/me_providers.dart';",
            'test/features/other_test.dart': "import 'package:deskilo/x.dart';",
          },
        ),
        // #3765 — a providers file also lists the Demo's container tests.
        ['test/core/demo/', 'test/features/me/space_offers_test.dart'],
      );
    });

    test('an ARB-only change lists test/i18n and nothing else', () {
      final skip = readNoImporterSearch(File('tool/preflight/test_map.json'));
      final consumers = <String, String>{
        'test/features/x_test.dart':
            "import 'package:deskilo/l10n/app_localizations.dart';",
      };
      expect(
        affectedTests(
          [
            'lib/l10n/_fragments/portal_en.arb',
            'lib/l10n/app_en.arb',
            'lib/l10n/app_localizations.dart',
            'lib/l10n/app_localizations_en.dart',
            'lib/features/task_recorder/domain/ui_vocabulary.g.dart',
          ],
          table,
          consumers,
          skipImporters: skip,
        ),
        ['test/i18n/'],
      );
    });

    test('a documentation-only change lists nothing', () {
      expect(list(['docs/AGENT_RULES.md', 'README.md']), isEmpty);
    });
  });
}
