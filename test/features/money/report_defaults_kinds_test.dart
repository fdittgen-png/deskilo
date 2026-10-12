// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1154 — the default-bands and preset ladders answer to the report-kind
// registry. The finding of #864 had survived here: an id the ladder did
// not know fell through to reminder level 1, so a typo edited a real
// document. Now an unknown id is EMPTY, and every registered kind has a
// default.
import 'package:deskilo/core/l10n/context_l10n.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/report_kind.dart';
import 'package:deskilo/features/money/presentation/report_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every registered kind has default bands, and they are not empty',
      () {
    for (final kind in reportKinds(reminderLevels: kMaxReminderLevels)) {
      final bands = defaultBandsForDoc(kind.id, englishL10n);
      expect(bands, isNot(ReportBands.empty), reason: kind.id);
      expect(bands.body, isNotEmpty, reason: kind.id);
    }
  });

  test('an unknown id is empty — never a reminder', () {
    expect(defaultBandsForDoc('reminder', englishL10n), ReportBands.empty);
    expect(defaultBandsForDoc('r0', englishL10n), ReportBands.empty);
    expect(defaultBandsForDoc('r${kMaxReminderLevels + 1}', englishL10n),
        ReportBands.empty);
    expect(defaultBandsForDoc('', englishL10n), ReportBands.empty);
  });

  test('the reminder levels resolve to their own defaults', () {
    final r1 = defaultBandsForDoc('r1', englishL10n);
    final r3 = defaultBandsForDoc('r3', englishL10n);
    expect(r1, isNot(ReportBands.empty));
    expect(r1, isNot(equals(r3)));
  });

  test('presets exist for every kind and are empty for an unknown id', () {
    for (final kind in reportKinds(reminderLevels: 2)) {
      final presets = presetsForDoc(kind.id, englishL10n);
      expect(presets, isNotEmpty, reason: kind.id);
      expect(presets.first.bands.body, isNotEmpty, reason: kind.id);
    }
    for (final preset in presetsForDoc('nope', englishL10n)) {
      expect(preset.bands, ReportBands.empty);
    }
  });
}
