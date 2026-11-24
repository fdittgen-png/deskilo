// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4431 (G17) -- what the expiry report prints: one line per lot on hand (and per piece of an item tracked piece by piece)
// that is expired at the reference date or expires after it, the letterhead, the reference date and what the list is. Pure:
// the words live in the bands (report_defaults_stock_expiry.dart), the dates and the quantities arrive written for the
// reader, and every row is the server's (`stock_expiry_report_v1`).
library;

import 'package:intl/intl.dart';

/// One line as the report prints it: names and amounts as the reader reads them, and the days (negative: past).
class StockExpiryLine {
  const StockExpiryLine({
    required this.item,
    required this.lot,
    required this.expiresOn,
    required this.days,
    required this.quantity,
    required this.place,
    this.variant = '',
    this.tag = '',
  });

  final String item;
  final String variant;
  final String lot;
  final String tag;
  final DateTime expiresOn;

  /// Days from the reference date to the expiry: below zero, it is that many days past.
  final int days;

  /// The quantity and its unit, written for the reader (`5 piece`, `0,35 kg`).
  final String quantity;

  /// The place's code and name.
  final String place;
}

/// The letterhead and the signature of the report: the business and its address, who prints it and when.
typedef StockExpiryLetter = ({String workspace, String address, String issuedBy, DateTime issued});

/// The data of the `stock_expiry` kind. [scope] is `expired`, `expiring` or `both`.
Map<String, Object?> stockExpiryReportData({
  required List<StockExpiryLine> lines,
  required DateTime asOf,
  required String scope,
  required String locale,
  required StockExpiryLetter letter,
}) {
  final date = DateFormat.yMMMd(locale).format;
  return {
    'workspace': letter.workspace,
    'workspace_address': letter.address,
    'as_of': date(asOf),
    'scope': scope,
    'issued': date(letter.issued),
    'issued_by': letter.issuedBy,
    'count': lines.length,
    'no_rows': lines.isEmpty,
    'rows': [
      for (final l in lines)
        {
          'item': l.item,
          'variant': l.variant,
          'lot': l.lot,
          'tag': l.tag,
          'place': l.place,
          'expires': date(l.expiresOn),
          // the size of the gap and which side of the date it is on: the words are the band's
          'days': '${l.days.abs()}',
          'state': switch (l.days) {
            < 0 => 'expired',
            0 => 'today',
            _ => 'expiring',
          },
          'quantity': l.quantity,
        },
    ],
  };
}
