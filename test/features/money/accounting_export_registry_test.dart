// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3334 -- the accounting export formats are a registry of contributions with
// declared source requirements, and the registry names exactly the file
// formats of the targets registry: a format added in one place without the
// other fails here. What each format reads is pinned by the parity goldens
// (`test/parity/golden/exports/source_requirements.golden`), not copied.
import 'package:deskilo/features/money/application/export/accounting_export_contribution.dart';
import 'package:deskilo/features/money/application/export/installed_accounting_exports.dart';
import 'package:deskilo/features/money/domain/accounting_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final registered = [for (final c in installedAccountingExports) c.formatId];
  final targeted = {
    for (final t in accountingTargets)
      if (t.format case final f?) f.id,
  };

  test(
    'the registry names every file format of the targets registry, once',
    () {
      expect(
        registered.toSet(),
        hasLength(registered.length),
        reason: 'a format id is registered once',
      );
      expect(
        registered.toSet(),
        targeted,
        reason:
            'a format in accountingTargets without a contribution (or the '
            'reverse) has no declared sources',
      );
    },
  );

  test('the declared requirements are coherent', () {
    for (final c in installedAccountingExports) {
      final r = c.requirements;
      if (r.archive) {
        expect(
          r.posting,
          ExportPosting.whenLocalBook,
          reason: '${c.formatId}: the archive reads postings of a local book',
        );
      }
      if (r.withOpening) {
        expect(
          r.posting,
          ExportPosting.only,
          reason: '${c.formatId}: opening balances come from the postings',
        );
      }
      if (r.named) {
        expect(
          r.posting,
          isNot(ExportPosting.none),
          reason: '${c.formatId}: naming accounts needs postings',
        );
      }
    }
  });

  test('exactly one format is the year archive', () {
    expect(
      [
        for (final c in installedAccountingExports)
          if (c.requirements.archive) c.formatId,
      ],
      ['bundle'],
    );
  });

  test('a format that declares nothing reads the documents only', () {
    final none = requirementsOf('no_such_format');
    expect(none.posting, ExportPosting.none);
    expect(none.named, isFalse);
    expect(none.withOpening, isFalse);
    expect(none.archive, isFalse);
  });
}
