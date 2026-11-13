// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_xlsx/deskilo_xlsx.dart';

/// #3884 -- [sheets] with a visible note line at the bottom of the sheet
/// named [sheetName] when [count] rows of it could not be read: a file that
/// is missing rows must not look complete. Nothing changes when [count] is 0.
List<XlsxSheet> _withUnreadableNote(
  List<XlsxSheet> sheets, {
  required String sheetName,
  required int count,
  required String note,
}) {
  if (count <= 0) return sheets;
  return [
    for (final sheet in sheets)
      if (sheet.name == sheetName)
        XlsxSheet(
          name: sheet.name,
          rows: [
            ...sheet.rows,
            [note],
          ],
          totals: sheet.totals,
        )
      else
        sheet,
  ];
}

/// #3884 -- the workspace export's workbook with the note that [count]
/// bookings (a status this version does not know) are not in it, worded by
/// [words], at the foot of its Reservations sheet.
List<XlsxSheet> withBookingsNote(
  List<XlsxSheet> sheets,
  int count,
  String Function(int count) words,
) => _withUnreadableNote(
  sheets,
  sheetName: 'Reservations',
  count: count,
  note: count > 0 ? words(count) : '',
);
