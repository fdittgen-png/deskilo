// SPDX-License-Identifier: 0BSD
//
// #864 — a report kind added later must gain export, import, a label
// and defaults, or fail here.
//
// Before the registry, a kind was a bare string repeated across five
// switches, two of which fell through to "then it must be a reminder".
// A kind added to four of them did not fail: it silently edited reminder
// level 1. That is exactly the shape of bug a count-and-compare test
// cannot catch, so this walks the registry itself and asks each member
// whether every surface knows about it.
import 'dart:io';

import 'package:deskilo/features/money/domain/report_kind.dart';
import 'package:deskilo/features/money/presentation/report_kind_labels.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/report_design_file.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two levels is enough to prove the reminder family is covered without
/// pinning a workspace's dunning configuration.
const _levels = 2;

void main() {
  final kinds = reportKinds(reminderLevels: _levels);

  test('the registry is not empty and every id is unique', () {
    expect(kinds, isNotEmpty);
    final ids = kinds.map((k) => k.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'duplicate ids: $ids');
  });

  test('every kind has a human label, and none falls back to its id', () {
    for (final kind in kinds) {
      final label = reportKindLabel(null, kind);
      expect(label.trim(), isNotEmpty, reason: kind.id);
      expect(label, isNot(kind.id),
          reason: '${kind.id} has no label — reportKindLabel fell back to '
              'the id, which is the "somebody forgot" case');
    }
  });

  test('every kind round-trips through the exchange format, exactly', () {
    final at = DateTime.utc(2026, 1, 1);
    for (final kind in kinds) {
      final bands = ReportBands(
        header: '# ${kind.id}',
        body: '{% for line in lines %}{{ line }}{% endfor %}',
        footer: '> ${kind.id} footer',
      );
      final first = buildReportDesignFile(
        kind: kind,
        language: 'fr',
        workspaceName: 'Test Space',
        bands: bands,
        exportedAt: at,
      );
      final parsed = parseReportDesignFile(first,
          expectedKind: kind, reminderLevels: _levels);
      expect(parsed.kindId, kind.id);
      final second = buildReportDesignFile(
        kind: kind,
        language: parsed.language,
        workspaceName: 'Test Space',
        bands: parsed.bands,
        exportedAt: at,
      );
      expect(second, first, reason: '${kind.id} does not round-trip');
    }
  });

  test('every kind reads and writes its own slot in the template', () {
    for (final kind in kinds) {
      final bands = ReportBands(header: 'H ${kind.id}', body: 'B', footer: 'F');
      final template = withBands(InvoicePdfTemplate.empty, kind, bands);
      expect(bandsOf(template, kind).header, 'H ${kind.id}',
          reason: '${kind.id} did not survive a write/read round trip');
      // And it must not have written into somebody else's slot.
      for (final other in kinds) {
        if (other.id == kind.id) continue;
        expect(bandsOf(template, other).header, isNot('H ${kind.id}'),
            reason: '${kind.id} wrote into ${other.id}');
      }
    }
  });

  test('every kind has shipped defaults', () {
    // defaultBandsForDoc lives in presentation and needs l10n, so this
    // asserts the source names each id rather than calling it.
    final defaults = File(
            'lib/features/money/presentation/report_defaults.dart')
        .readAsStringSync();
    for (final kind in kinds) {
      if (kind.isReminder) continue; // one generator covers every level
      expect(defaults, contains("'${kind.id}'"),
          reason: '${kind.id} has no branch in defaultBandsForDoc');
    }
  });

  test('the editor no longer keeps its own list of kinds', () {
    final editor = File(
            'lib/features/money/presentation/widgets/invoice_template_sheet.dart')
        .readAsStringSync();
    // The five hand-maintained switches this registry replaced.
    expect(editor, isNot(contains('_extraDocs')),
        reason: 'the extras constant is back');
    expect(editor, contains('reportKinds(reminderLevels:'),
        reason: 'the chip list must come from the registry');
    expect(editor, isNot(contains("'space_codes' =>")),
        reason: 'a per-id switch is back in the editor');
  });

  test('the exchange format carries instructions, generated from the '
      'constants the renderer uses', () {
    final howTo = reportDesignInstructions();
    expect(howTo['placeholders'], InvoicePdfTemplate.placeholders,
        reason: 'the file must advertise the placeholders that exist, '
            'not a copy that can drift');
    expect(howTo['markup'], isA<Map<String, Object>>());
    expect(howTo['bands'], isA<Map<String, Object>>());
    expect(howTo['rules'], isA<List<Object>>());
  });
}
