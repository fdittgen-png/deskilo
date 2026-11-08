// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3432 -- an export file that reads the workspace's tax reference is covered
// by the "context not ready" check of `AccountingExportRun.start()`
// (`_needsWorkspaceReference` in accounting_export_context.dart). That list
// is kept by hand, so this pins which export files read the reference: a new
// one fails here until the person adding it has put its format kind in the
// list (and added its refusal case to accounting_export_context_not_ready_test).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _covered = {
  'accounting_export_context.dart',
  'accounting_export_german.dart', // gobd, datev
  'accounting_export_handover.dart', // archiveBundle, gobd
  'accounting_export_run.dart', // saft, saftPortugal
  'accounting_export_saft.dart', // saftFinancial
  'accounting_export_sage.dart', // sage
  'accounting_export_swiss.dart', // swissKmu, swissBanana, archiveBundle
};

void main() {
  test('only the covered export files read the workspace tax reference', () {
    final reading = {
      for (final f in handWrittenDartFiles('lib/features/money/presentation'))
        if (f.uri.pathSegments.last.startsWith('accounting_export_') &&
            f.readAsStringSync().contains('workspaceTaxReference('))
          f.uri.pathSegments.last,
    };
    expect(
      reading.difference(_covered),
      isEmpty,
      reason:
          'an export file reads the workspace reference: add its format kind '
          'to _needsWorkspaceReference and a refusal case, then list the file',
    );
    expect(
      _covered.difference(reading),
      isEmpty,
      reason: 'these no longer read it: delete them from the list',
    );
    expect(File('lib/features/money/presentation/accounting_export_context.dart')
        .existsSync(), isTrue);
  });
}
