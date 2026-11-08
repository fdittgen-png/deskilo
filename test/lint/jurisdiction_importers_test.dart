// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the application reaches a country's add-on through the
// contract and the installed compositions (`installed_*.dart`), never by
// importing `deskilo_jurisdiction_<country>` itself: a generic file that names
// one country's package is a file the removability proof cannot cross.
//
// RATCHET over comment-free source: the files outside the composition that
// still import a country add-on may only fall. Today's three are checklist
// items of #3429 (the GB MTD boxes, the Italian stamp duty and register).
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The files that still import a country add-on, each with its item.
const _importers = <String, String>{
  'lib/features/money/domain/mtd_boxes.dart': '#3429 presentation / filing: GB MTD',
  'lib/features/money/domain/stamp_duty.dart': '#3429 invoice validity: IT stamp duty',
  'lib/features/money/domain/vat_register_it.dart': '#3429 VAT registers: IT',
};

void main() {
  test('only the compositions import a country add-on; the rest only falls', () {
    final importRe = RegExp(
      r'''^\s*(?:import|export)\s+['"]package:deskilo_jurisdiction_(?:ca|ch|de|es|fr|gb|it|pl)/''',
    );
    final found = <String>{
      for (final f in handWrittenDartFiles('lib'))
        if (!f.uri.pathSegments.last.startsWith('installed_') &&
            f.readAsLinesSync().any(importRe.hasMatch))
          f.path.replaceFirst(RegExp(r'^.*?(?=lib/)'), ''),
    };
    expect(
      found.difference(_importers.keys.toSet()),
      isEmpty,
      reason:
          'a generic file asks the resolver; a country package is imported '
          'by an installed_*.dart composition only',
    );
    expect(
      _importers.keys.toSet().difference(found),
      isEmpty,
      reason: 'progress: delete the entries that no longer import one',
    );
  });
}
