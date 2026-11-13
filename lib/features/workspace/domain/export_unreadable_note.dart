// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_xlsx/deskilo_xlsx.dart';

/// #3884 -- [sheets] with a visible note line at the bottom of the sheet
/// named [sheetName] when [count] rows of it could not be read: a file that
/// is missing rows must not look complete. Nothing changes when [count] is 0.
List<XlsxSheet> withUnreadableNote(
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
