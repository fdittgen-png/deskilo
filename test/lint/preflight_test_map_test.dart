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
          if (!File(t).existsSync() && !Directory(t).existsSync()) t,
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
        ['test/features/me/space_offers_test.dart'],
      );
    });

    test('a documentation-only change lists nothing', () {
      expect(list(['docs/AGENT_RULES.md', 'README.md']), isEmpty);
    });
  });
}
