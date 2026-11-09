// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2374 -- the Business Central General Journal as a workbook: the posting
// engine's entries, one row per posting line, in the column set the
// "Edit in Excel" shape of that journal names. The fallback for a company
// that is not connected to the API target.
//
// A document's rows balance: every posting is balanced by the engine, a
// debit is a positive amount and a credit a negative one, so the rows of one
// `Document No.` sum to zero. A tax line carries the VAT product posting group
// mapped from its rate group (the tax key); a rate group with no mapping
// stops the file and is named -- nothing is written with a guessed group.
//
// What is stated by the issue and NOT verified against a company: the exact
// column names and the way Business Central treats a VAT group on a direct
// G/L line (the lines are written as direct postings: no `Gen. Posting Type`,
// the group carried for the importer's reconciliation). A live import is NOT
// RUN until the owner provides a company.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:deskilo_xlsx/deskilo_xlsx.dart';

/// The columns of the journal, in order.
const List<String> _columns = [
  'Posting Date',
  'Document Type',
  'Document No.',
  'External Document No.',
  'Account Type',
  'Account No.',
  'Description',
  'Amount',
  'Bal. Account Type',
  'Bal. Account No.',
  'Gen. Posting Type',
  'VAT Bus. Posting Group',
  'VAT Prod. Posting Group',
  'Shortcut Dimension 1 Code',
  'Shortcut Dimension 2 Code',
];

/// What the journal of a year is.
sealed class BcJournal {
  const BcJournal();
}

/// The workbook, and the table it was written from (the header first).
final class BcJournalFile extends BcJournal {
  const BcJournalFile(this.bytes, this.table);
  final Uint8List bytes;
  final List<List<Object?>> table;
}

/// These rate groups have no VAT product posting group; nothing was written.
final class BcJournalUnmapped extends BcJournal {
  const BcJournalUnmapped(this.taxKeys);
  final List<String> taxKeys;
}

/// The Business Central document type of an event; '' where it has none.
String _documentType(PostingKind kind) => switch (kind) {
  PostingKind.invoice => 'Invoice',
  PostingKind.creditNote => 'Credit Memo',
  PostingKind.receipt => 'Payment',
  PostingKind.refund => 'Refund',
  _ => '',
};

/// A line's signed amount in major units: a debit positive, a credit negative.
double _signed(PostingLine l) {
  final minor = l.debit.minor - l.credit.minor;
  return minor / math.pow(10, l.debit.exponent);
}

bool _isTax(PostingLine l) =>
    l.role == BookRole.vatOutput || l.role == BookRole.vatInput;

/// The VAT product posting group each rate group of [postings] is written
/// under until the company's own are mapped: the rate group's key, upper-case
/// (`standard` -> `STANDARD`). Editable in the workbook before it is imported;
/// the group names of a company are its own and are not known here.
Map<String, String> bcDefaultVatGroups(List<Posting> postings) => {
  for (final p in postings)
    for (final l in p.lines)
      if (_isTax(l)) l.qualifier ?? '': (l.qualifier ?? '').toUpperCase(),
};

/// The journal of [postings]. [vatProductGroups] maps a rate group (the
/// qualifier of a tax line) to the company's VAT product posting group.
BcJournal buildBcJournalXlsx(
  List<Posting> postings, {
  required Map<String, String> vatProductGroups,
  required String Function(Posting posting) description,
}) {
  final unmapped = <String>{
    for (final p in postings)
      for (final l in p.lines)
        if (_isTax(l) && (vatProductGroups[l.qualifier ?? ''] ?? '').isEmpty)
          l.qualifier ?? '',
  };
  if (unmapped.isNotEmpty) return BcJournalUnmapped(unmapped.toList()..sort());
  final rows = <List<Object?>>[_columns];
  for (final p in postings) {
    for (final l in p.lines) {
      final group = _isTax(l) ? vatProductGroups[l.qualifier ?? ''] ?? '' : '';
      rows.add([
        XlsxDate(p.date),
        _documentType(p.kind),
        p.documentNumber,
        p.documentNumber,
        'G/L Account',
        l.accountCode,
        description(p),
        XlsxAmount(_signed(l)),
        '',
        '',
        '',
        '',
        group,
        '',
        '',
      ]);
    }
  }
  return BcJournalFile(
    buildXlsx([XlsxSheet(name: 'General Journal', rows: rows)]),
    rows,
  );
}
