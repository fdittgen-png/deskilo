// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4120 -- an archive or an export names, in its own summary, the invoices it
// filed without their stored original and why, instead of filing them
// silently. A file of the archive, written in English like its handover.
import 'dart:convert' show utf8;

import 'package:meta/meta.dart';

import '../../../core/text/csv.dart';
import 'invoice_originals.dart';

/// The summary's file name inside an archive or an export.
@visibleForTesting
const originalsSummaryFileName = 'invoices-without-original.csv';

/// One invoice filed without its stored original: its number, and where the
/// filed bytes came from instead ([source], never
/// [InvoiceDocumentSource.original]) with the server's words when it refused.
typedef FiledWithoutOriginal = ({
  String number,
  InvoiceDocumentSource source,
  String why,
});

/// Why, in the summary's words.
@visibleForTesting
String originalMissingReason(InvoiceDocumentSource source) => switch (source) {
  InvoiceDocumentSource.notKept => 'issued before originals were kept',
  InvoiceDocumentSource.tooLarge => 'larger than the store keeps',
  InvoiceDocumentSource.refused => 'refused when it was to be kept',
  InvoiceDocumentSource.mismatch =>
    'the stored bytes do not match their digest',
  InvoiceDocumentSource.notYetKept => 'not kept yet',
  InvoiceDocumentSource.original => '',
};

/// The summary's files: none when every invoice was filed as its original.
Map<String, List<int>> originalsSummaryFiles(List<FiledWithoutOriginal> rows) {
  if (rows.isEmpty) return const {};
  final lines = [
    'invoice_number;filed_as;reason;detail',
    for (final r in rows)
      [
        csvCell(r.number, quoteEmpty: true),
        'copy rendered now',
        csvCell(originalMissingReason(r.source), quoteEmpty: true),
        csvCell(r.why, quoteEmpty: true),
      ].join(';'),
  ];
  return {originalsSummaryFileName: utf8.encode('${lines.join('\r\n')}\r\n')};
}
