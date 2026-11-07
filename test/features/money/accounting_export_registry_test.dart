// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3334 -- the accounting export formats are ONE list: the file formats of the
// targets registry, each declaring its writer family and the sources it reads
// where it is defined. There is no second registry to drift (and nothing in
// SQL or TS to generate: neither holds a list of export format ids). What each
// format reads is pinned by the parity goldens
// (`test/parity/golden/exports/source_requirements.golden`), not copied here.
import 'package:deskilo/features/money/domain/accounting_capability.dart';
import 'package:deskilo/features/money/domain/accounting_export_formats.dart';
import 'package:deskilo/features/money/domain/accounting_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every target format is the one definition of its id', () {
    final ids = <String>{};
    for (final t in accountingTargets) {
      final f = t.format;
      if (f == null) continue;
      expect(
        identical(exportFormatOf(f.id), f),
        isTrue,
        reason: '${f.id}: two different definitions share an id',
      );
      ids.add(f.id);
    }
    expect(exportFormats.map((f) => f.id).toSet(), ids);
    expect(
      exportFormats.map((f) => f.id).toSet(),
      hasLength(exportFormats.length),
    );
  });

  test('the declared sources are coherent', () {
    for (final f in exportFormats) {
      final r = f.sources;
      if (r.archive) {
        expect(
          r.posting,
          ExportPosting.whenLocalBook,
          reason: '${f.id}: the archive reads postings of a local book',
        );
      }
      if (r.withOpening) {
        expect(
          r.posting,
          ExportPosting.only,
          reason: '${f.id}: opening balances come from the postings',
        );
      }
      if (r.named) {
        expect(
          r.posting,
          isNot(ExportPosting.none),
          reason: '${f.id}: naming accounts needs postings',
        );
      }
    }
  });

  test('exactly one format is the year archive', () {
    expect(
      [
        for (final f in exportFormats)
          if (f.sources.archive) f.id,
      ],
      ['bundle'],
    );
  });

  test('a format nobody offers reads the documents only', () {
    expect(exportFormatOf('no_such_format'), isNull);
    final none = sourcesOf('no_such_format');
    expect(none.posting, ExportPosting.none);
    expect(none.named, isFalse);
    expect(none.withOpening, isFalse);
    expect(none.archive, isFalse);
  });

  test('a target with no file format acquires no builder: jpk_kr_pl stays '
      'specification-needed and not producible', () {
    final ids = exportFormats.map((f) => f.id).toSet();
    for (final t in accountingTargets) {
      if (t.format == null) {
        expect(
          ids,
          isNot(contains(t.id)),
          reason: '${t.id} has no file format, so no export builder',
        );
      }
    }
    expect(ids, isNot(contains('jpk_kr_pl')));
    final jpk = capabilityOfTarget('jpk_kr_pl');
    expect(jpk.state, QualificationState.specificationNeeded);
    expect(jpk.producible, isFalse);
  });
}
