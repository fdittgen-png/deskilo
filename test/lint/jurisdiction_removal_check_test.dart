// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3337 (of #3328) -- the physical removal check can say no. A fixture tree
// proves each blocker; the real tree pins what is true today: the Italian
// add-on is removable at the source level, the standards package is not.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/jurisdiction_removal/removal_check.dart';
import 'lint_sources.dart';

void _write(String root, String path, String text) => File('$root/$path')
  ..createSync(recursive: true)
  ..writeAsStringSync(text);

String _pubspec(String name, [List<String> deps = const []]) =>
    'name: $name\ndependencies:\n${[for (final d in deps) '  $d:\n    path: ../$d\n'].join()}';

void main() {
  late String root;

  setUp(() {
    final fixture = createTemporaryFixture('removal_check');
    root = fixture.directory.path;
    _write(root, 'packages/shared/pubspec.yaml', _pubspec('shared'));
    _write(root, 'packages/it/pubspec.yaml', _pubspec('it', ['shared']));
    _write(root, 'packages/fr/pubspec.yaml', _pubspec('fr', ['shared']));
    _write(
      root,
      'lib/installed_profiles.dart',
      "import 'package:it/it.dart';\n",
    );
    _write(root, 'lib/money.dart', "import 'package:shared/shared.dart';\n");
  });

  tearDown(() => directoryAt(root).deleteSync(recursive: true));

  test('a module only the composition list registers is removable', () {
    final report = removalCheck(root, 'it');
    expect(report.blockers, isEmpty);
    expect(report.removable, isTrue);
    expect(report.runtime, isFalse, reason: 'the runtime half was not asked');
  });

  test('a shared serializer another country uses blocks its removal', () {
    final report = removalCheck(root, 'shared');
    expect(
      report.blockers.map((b) => '$b'),
      containsAll([
        'dependentPackage: it',
        'dependentPackage: fr',
        'dependentSource: lib/money.dart',
      ]),
    );
    expect(report.removable, isFalse);
  });

  test('application source importing the module blocks it', () {
    _write(root, 'lib/money.dart', "import 'package:it/it.dart';\n");
    final report = removalCheck(root, 'it');
    expect(report.blockers.map((b) => '$b'), ['dependentSource: lib/money.dart']);
  });

  test('an enabled capability, a pending submission and a correction route '
      'each block, and say the runtime half was checked', () {
    final report = removalCheck(
      root,
      'it',
      facts: const RemovalFacts(
        enabledCapabilities: ['invoice_profile.fatturaPa'],
        pendingSubmissions: 2,
        neededCorrectionRoutes: ['linked_correction'],
      ),
    );
    expect(report.runtime, isTrue);
    expect(report.blockers.map((b) => b.kind), [
      BlockerKind.enabledCapability,
      BlockerKind.pendingSubmission,
      BlockerKind.correctionRoute,
    ]);
  });

  test('facts with nothing outstanding leave the module removable', () {
    final report = removalCheck(
      root,
      'it',
      facts: RemovalFacts.fromJson(const {}),
    );
    expect(report.runtime, isTrue);
    expect(report.removable, isTrue);
  });

  test('today: the Italian add-on is still needed by the host\'s registro IVA '
      'and stamp duty (the Natura table), and the standards package by many', () {
    final it = removalCheck('.', 'deskilo_jurisdiction_it');
    expect(
      it.blockers.map((b) => '$b'),
      unorderedEquals([
        'dependentSource: lib/features/money/domain/stamp_duty.dart',
        'dependentSource: lib/features/money/domain/vat_register_it.dart',
      ]),
      reason:
          'the host reaches the Italian add-on through its installed_* lists '
          'and, for the Natura table, from these two files; fewer is progress, '
          'more is a new dependency to justify',
    );
    final standards = removalCheck('.', 'deskilo_jurisdiction_standards');
    expect(
      standards.blockers.map((b) => b.subject),
      containsAll([
        'deskilo_jurisdiction_it',
        'deskilo_jurisdiction_fr',
        'lib/core/text/csv.dart',
      ]),
    );
  });
}
