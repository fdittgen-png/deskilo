// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2861 — the person-facing workbook is in the reader's language; the
// CSV machine copy keeps the stable keys whatever the language.
import 'package:deskilo/core/files/xlsx.dart';
import 'package:deskilo/features/workspace/domain/workspace_export_labels.dart';
import 'package:deskilo/features/workspace/presentation/workspace_export_words.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final _sheets = [
  XlsxSheet(
    name: 'Check-ins',
    rows: [
      ['reservation_id', 'starts_at', 'brand_new_column'],
      ['r1', DateTime(2026, 5, 13, 9), const XlsxAmount(12.5)],
    ],
  ),
  const XlsxSheet(
    name: 'book_profiles',
    rows: [
      ['id'],
    ],
  ),
];

List<XlsxSheet> _in(String language) => localizeExportSheets(
  _sheets,
  workspaceExportLabels(lookupAppLocalizations(Locale(language))),
);

void main() {
  test('the headers and sheet names are in the reader\'s language', () {
    final en = _in('en');
    final fr = _in('fr');
    expect(en.first.name, 'Attendance');
    expect(fr.first.name, 'Présences');
    expect(en.first.rows.first, ['Booking', 'Starts', 'Brand new column']);
    expect(fr.first.rows.first.take(2), ['Réservation', 'Début']);
    expect(fr.last.name, 'Profils comptables');
    expect(
      fr.first.rows[1],
      _sheets.first.rows[1],
      reason: 'only names and headers change, never a value',
    );
  });

  test('the CSV copy keeps the stable keys in every language', () {
    final csv = exportSheetCsv(_sheets.first);
    expect(
      csv.split('\r\n').first,
      'reservation_id,starts_at,brand_new_column',
    );
    expect(csv, contains('r1,2026-05-13T09:00:00.000,12.5'));
    expect(exportKeyOf('Check-ins'), 'check_ins');
  });

  test('names stay unique after Excel\'s 31-character cut', () {
    final sheets = localizeExportSheets(
      [
        const XlsxSheet(name: 'a', rows: []),
        const XlsxSheet(name: 'b', rows: []),
      ],
      ExportLabels(
        sheet: (_) => 'A name far longer than thirty-one characters',
        column: (k) => k,
        about: _about,
      ),
    );
    expect(
      sheets.map((s) => s.name.length),
      everyElement(lessThanOrEqualTo(31)),
    );
    expect(sheets.map((s) => s.name.toLowerCase()).toSet().length, 2);
  });

  test('the About sheet names every sheet with its rows', () {
    final about = exportAboutSheet(
      labels: _about,
      workspaceName: 'Pézenas',
      generatedAt: DateTime(2026, 10, 22, 21),
      timeZone: 'Europe/Paris',
      currency: 'EUR',
      schemaVersion: 540,
      sheets: _sheets,
    );
    expect(about.rows.last, ['book_profiles', 0]);
    expect(
      about.rows.any((r) => r.length == 2 && r[0] == 'Check-ins' && r[1] == 1),
      isTrue,
    );
  });
}

const _about = ExportAboutLabels(
  title: 'About',
  workspace: 'Workspace',
  generatedOn: 'Generated on',
  timeZone: 'Time zone',
  currency: 'Currency',
  schema: 'Schema',
  contents: 'Contents',
  sheet: 'Sheet',
  rows: 'Rows',
  machineCopy: 'CSV copy in data/',
);
