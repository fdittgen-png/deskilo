// SPDX-License-Identifier: AGPL-3.0-or-later

/// #2365 — `DateLet` (column index 14) is mandatory whenever `EcritureLet`
/// (index 13) is filled: it is the date the lettering was made, i.e. the
/// date of the last entry that took part in it. The builders write the
/// letter (the invoice number) on every row of an invoice's group; this
/// fills the date from the group itself, so the two can never disagree.
/// Dates are the `YYYYMMDD` text of `EcritureDate` (index 3), which sorts
/// as a date.
List<List<String>> withLetteringDates(List<List<String>> rows) {
  final last = <String, String>{};
  for (final row in rows) {
    final letter = row[13];
    if (letter.isEmpty) continue;
    final seen = last[letter];
    if (seen == null || row[3].compareTo(seen) > 0) last[letter] = row[3];
  }
  return [
    for (final row in rows)
      if (row[13].isEmpty)
        row
      else
        [...row.take(14), last[row[13]]!, ...row.skip(15)],
  ];
}
