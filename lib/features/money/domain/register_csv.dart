// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3606 — the invoice register's selected invoices as a CSV file: one row per
// invoice under the register's own columns, in the reader's language. The
// amount is a plain decimal in its own currency's exponent, the currency in
// its own column, and there is no total row (two currencies are never
// summed). Text cells go through the shared cell writer, which quotes and
// keeps a spreadsheet from running a cell that starts with =, +, - or @.
// UTF-8 with a byte order mark and CRLF line ends, as the other table
// exports are written (bi_report_export.dart).
//
// This is not an accounting file: the year's audit export stays whole and
// stays on the register's own command (accounting_export_source.dart).
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show isoDay;

import '../../../core/files/file_names.dart';
import '../../../core/text/csv.dart';

/// The header words, in the reader's language.
typedef RegisterCsvHeader = ({
  String date,
  String number,
  String member,
  String period,
  String amount,
  String currency,
  String status,
});

/// [invoices] as the register's CSV: [period] and [status] give a row's
/// words as the register shows them.
Uint8List registerCsv(
  List<Invoice> invoices, {
  required RegisterCsvHeader header,
  required String Function(Invoice invoice) period,
  required String Function(Invoice invoice) status,
}) {
  final lines = <String>[
    [
      header.date,
      header.number,
      header.member,
      header.period,
      header.amount,
      header.currency,
      header.status,
    ].map(csvCell).join(','),
    for (final i in invoices)
      [
        isoDay(i.issuedAt),
        csvCell(i.number),
        csvCell(i.memberName),
        csvCell(period(i)),
        csvAmount(i.totalCents, i.currency),
        csvCell(i.currency),
        csvCell(status(i)),
      ].join(','),
  ];
  return Uint8List.fromList([
    0xEF, 0xBB, 0xBF, // UTF-8 byte order mark, as the other table exports.
    ...utf8.encode('${lines.join('\r\n')}\r\n'),
  ]);
}

/// The file's name: the workspace and the day it was made.
String registerCsvName(String workspaceName, DateTime now) =>
    'deskilo-invoices-${safeFileSlug(workspaceName)}-${isoDay(now)}.csv';
