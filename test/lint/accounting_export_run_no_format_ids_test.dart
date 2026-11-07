// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3334 -- the accounting export run has no format-id branches. A format is
// registered once (`installed_accounting_exports.dart`) with the writer family
// the run dispatches on (`ExportKind`, switched exhaustively); the run files do
// not name a format by its id. A new format is a registration, not an edit to
// the run.
import 'package:deskilo/features/money/domain/accounting_export_formats.dart';
import 'package:deskilo/features/money/domain/accounting_export_sources.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  final ids = [for (final f in exportFormats) f.id];

  test('no accounting export run file names a registered format id', () {
    final run = filesWithExtension(
      'lib/features/money/presentation',
      '.dart',
    ).where((f) => f.uri.pathSegments.last.startsWith('accounting_export'));
    expect(run, isNotEmpty);
    final bad = <String>[];
    for (final f in run) {
      for (final (i, line) in f.readAsLinesSync().indexed) {
        if (line.trimLeft().startsWith('//')) continue;
        for (final id in ids) {
          if (line.contains("'$id'")) {
            bad.add('${f.path}:${i + 1}: $id');
          }
        }
      }
    }
    expect(
      bad,
      isEmpty,
      reason:
          'dispatch on ExportKind (the registration), not on a format '
          'id:\n${bad.join('\n')}',
    );
  });

  test('every writer family is registered by a format, and the run covers '
      'every family', () {
    final used = {for (final f in exportFormats) f.kind};
    expect(
      used,
      ExportKind.values.toSet(),
      reason: 'a family nobody is registered under is dead code',
    );
    final run = filesWithExtension(
      'lib/features/money/presentation',
      '.dart',
    ).firstWhere((f) => f.path.endsWith('accounting_export_run.dart'));
    final text = run.readAsStringSync();
    for (final k in ExportKind.values) {
      expect(
        text,
        contains('ExportKind.${k.name}'),
        reason: 'the run handles ${k.name}',
      );
    }
  });

  test('the Portuguese SAF-T is its own family, registered once', () {
    expect(
      [
        for (final f in exportFormats)
          if (f.kind == ExportKind.saftPortugal) f.id,
      ],
      ['saft_pt'],
    );
  });
}
