// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3337 (of #3328) -- the physical removal check can say no. A fixture tree
// proves each blocker; the real tree pins what is true today: the Italian
// add-on is removable at the source level, the standards package is not.
import 'dart:convert';
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
    expect(report.blockers.map((b) => '$b'), [
      'dependentSource: lib/money.dart',
    ]);
  });

  test(
    'the answer of the facts function blocks by id: a channel, each '
    'unsettled transmission and each replacement that still has to leave',
    () {
      final report = removalCheck(
        root,
        'it',
        facts: RemovalFacts.fromJson(const {
          'enabled_capabilities': [
            {'capability': 'einvoice_channel.it_sdi', 'provider': 'it_sdi'},
          ],
          'unsettled_transmissions': [
            {'transmission_id': 'tx-1', 'invoice_id': 'inv-1', 'phase': 'sent'},
            {
              'transmission_id': 'tx-2',
              'invoice_id': 'inv-2',
              'phase': 'uncertain',
            },
          ],
          'needed_correction_routes': [
            {'invoice_id': 'inv-9', 'replaces_invoice_id': 'inv-8'},
          ],
        }),
      );
      expect(report.runtime, isTrue);
      expect(report.blockers.map((b) => '$b'), [
        'enabledCapability: einvoice_channel.it_sdi',
        'pendingSubmission: tx-1',
        'pendingSubmission: tx-2',
        'correctionRoute: inv-9',
      ]);
    },
  );

  test('facts with nothing outstanding leave the module removable', () {
    final report = removalCheck(
      root,
      'it',
      facts: RemovalFacts.fromJson(const {
        'enabled_capabilities': <Object?>[],
        'unsettled_transmissions': <Object?>[],
        'needed_correction_routes': <Object?>[],
      }),
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

  test('retiring the Swiss add-on leaves bank matching and the RF/SCOR '
      'reference working: nothing in the host source needs it', () {
    final ch = removalCheck('.', 'deskilo_jurisdiction_ch');
    expect(
      ch.blockers.where((b) => b.toString().startsWith('dependentSource')),
      isEmpty,
      reason:
          'the QR bill, the QR-IBAN rule and the slip are the add-on\'s; the '
          'QRR mod-10 and ISO 11649 SCOR stay shared standards, so bank '
          'matching names an invoice by either reference without it',
    );
  });

  group('installation scope', () {
    const clean = {
      'scope': 'installation',
      'workspaces_checked': 3,
      'workspaces': <Object?>[],
    };
    const secondSpaceDirty = {
      'scope': 'installation',
      'workspaces_checked': 2,
      'workspaces': [
        {
          'workspace_id': 'ws-2',
          'enabled_capabilities': <Object?>[],
          'unsettled_transmissions': [
            {'transmission_id': 'tx-21', 'phase': 'uncertain'},
          ],
          'needed_correction_routes': <Object?>[],
        },
      ],
    };
    // one space's clean answer; the dirty work is in ANOTHER space
    const oneSpaceClean = {
      'enabled_capabilities': <Object?>[],
      'unsettled_transmissions': <Object?>[],
      'needed_correction_routes': <Object?>[],
    };

    test('a one-space clean answer is not a proof for the installation', () {
      final report = removalCheck(
        root,
        'it',
        facts: RemovalFacts.fromJson(oneSpaceClean),
      );
      expect(
        report.removable,
        isTrue,
        reason: 'nothing found in what was asked',
      );
      expect(report.proven, isFalse, reason: 'the other spaces were not asked');
    });

    test('the installation answer names the dirty space and the attempt', () {
      final report = removalCheck(
        root,
        'it',
        facts: RemovalFacts.fromJson(secondSpaceDirty),
      );
      expect(report.blockers.map((b) => '$b'), [
        'pendingSubmission: tx-21 (space ws-2)',
      ]);
      expect(report.proven, isFalse);
    });

    test('a clean installation answer over a clean source proves it', () {
      final report = removalCheck(
        root,
        'it',
        facts: RemovalFacts.fromJson(clean),
      );
      expect(report.proven, isTrue);
    });

    // the command line, on a module the real tree can lose today
    const module = 'deskilo_jurisdiction_ch';
    Future<ProcessResult> cli(Map<String, Object?>? facts) async {
      final args = ['run', 'tool/jurisdiction_removal_check.dart', module];
      if (facts != null) {
        final dir = createTemporaryFixture('removal_cli').directory.path;
        final file = File('$dir/facts.json')
          ..writeAsStringSync(jsonEncode(facts));
        args.addAll(['--facts', file.path]);
      }
      return Process.run('dart', args);
    }

    test('the command line: no facts, or a one-space answer, exits 3 '
        '("not a proof"); a dirty space exits 1 naming it; a clean '
        'installation exits 0', () async {
      final none = await cli(null);
      expect(none.exitCode, 3, reason: '${none.stdout}${none.stderr}');
      final oneSpace = await cli(oneSpaceClean);
      expect(oneSpace.exitCode, 3);
      expect('${oneSpace.stdout}', contains('NOT CHECKED  the other spaces'));
      final dirty = await cli(secondSpaceDirty);
      expect(dirty.exitCode, 1);
      expect('${dirty.stdout}', contains('tx-21 (space ws-2)'));
      final proven = await cli(clean);
      expect(proven.exitCode, 0, reason: '${proven.stdout}${proven.stderr}');
    });
  });
}
