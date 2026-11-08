// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3432/#3403 -- an accounting export reads the workspace's tax reference ONCE,
// at the start of the run (`AccountingExportRun.taxReference`, set by the
// "context not ready" check in `accounting_export_context.dart`), and every
// later step states that reference. An export file that reads
// `workspaceTaxReference(` itself would read it again after an await, where
// the context may already be gone.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  test('only the start-of-run check reads the workspace tax reference', () {
    final reading = {
      for (final f in handWrittenDartFiles('lib/features/money/presentation'))
        if (f.uri.pathSegments.last.startsWith('accounting_export_') &&
            RegExp(r'(?<!watch|require)workspaceTaxReference\(', caseSensitive: false)
                .hasMatch(f.readAsStringSync()))
          f.uri.pathSegments.last,
    };
    expect(
      reading,
      {'accounting_export_context.dart'},
      reason:
          'read the reference through AccountingExportRun.taxReference, never '
          'again after an await',
    );
  });
}
