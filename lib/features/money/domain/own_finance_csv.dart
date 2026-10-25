// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C3 — Me › Finances: my own documents of ONE workspace as a CSV
// file, as the overview read them from that workspace's host. One file per
// workspace: currencies are never summed together and no total is
// invented. Text cells go through the shared cell writer (quoting, line
// breaks and formula injection); amounts are numbers in the currency's own
// exponent, never a universal /100; the document state is the server's.
//
// C7: the workspace's payments follow its invoices, every page of them as
// its own host answers, each row naming the record and the source it was
// read on. Amounts are never masked: the file is the export the person
// asked for.
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/files/file_names.dart';
import '../../../core/i18n/currencies.dart';
import '../../../core/text/csv.dart';
import '../../../core/time/date_text.dart';
import 'account_activity.dart';
import 'finance_overview.dart';
import 'finance_sources.dart';

/// The columns, in order: stable identifiers a spreadsheet can map.
const List<String> _columns = [
  'number',
  'workspace',
  'issued_at',
  'due_on',
  'state',
  'currency',
  'total',
  'paid',
  'remaining',
  'reminders',
  'invoice_id',
  // C7, appended so a mapping by the columns above still holds.
  'record',
  'source',
  'paid_at',
  'payment_id',
  'description',
];

/// [count] empty cells.
Iterable<String> _blank(int count) => List.filled(count, '');

/// [minor] units of [currency] as a plain decimal number (`-12.50`).
String _amount(int minor, String currency) {
  final digits = Currencies.minorDigits(currency);
  if (digits == 0) return '$minor';
  final sign = minor < 0 ? '-' : '';
  final text = minor.abs().toString().padLeft(digits + 1, '0');
  final cut = text.length - digits;
  return '$sign${text.substring(0, cut)}.${text.substring(cut)}';
}

/// The due date as the host wrote it (a date, no zone to convert).
String _day(DateTime? on) => on == null ? '' : isoDay(on);

/// #2557 C4 — the first cell of a coverage note: a row that is not a
/// document, after the documents, saying the file is not complete.
const _noteMarker = '# unavailable_source';

/// The host part of [source] (an origin), or [source] itself.
String _host(String source) {
  final host = Uri.tryParse(source)?.host ?? '';
  return host.isEmpty ? source : host;
}

/// One payment as a row under [_columns]: its reference where an invoice
/// has its number, its amount as paid, its status as the provider's.
String _paymentRow(AccountActivity p, String source) => [
  csvCell(p.reference),
  csvCell(p.workspaceName),
  ..._blank(2),
  csvCell(p.status),
  csvCell(p.currency),
  '',
  if (p.amountCents case final minor?) _amount(minor, p.currency) else '',
  ..._blank(3),
  'payment',
  csvCell(source),
  p.occurredAt.toUtc().toIso8601String(),
  csvCell(p.id),
  csvCell(p.description),
].join(',');

/// The invoices of [overview], newest first (the id breaks a tie), then
/// [payments] (C7) newest first, as CSV rows under [_columns]; UTF-8, CRLF
/// line ends. When a host did not answer, for the documents or for the
/// payments, one note row per such host follows (the marker and the host,
/// both through [csvCell]), so the file itself says it holds only what the
/// other hosts returned.
Uint8List ownFinanceCsv(FinanceOverview overview, {OwnPayments? payments}) {
  final invoices = [...overview.invoices]
    ..sort((a, b) {
      final byDate = b.issuedAt.compareTo(a.issuedAt);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
  final notes = {
    for (final source in overview.notAnswered) _host(source),
    if (payments != null && !payments.complete) payments.source.name,
  };
  final lines = <String>[
    _columns.join(','),
    for (final i in invoices)
      [
        csvCell(i.number),
        csvCell(i.workspaceName),
        // The instant, in UTC: no device zone decides the day.
        i.issuedAt.toUtc().toIso8601String(),
        _day(i.dueOn),
        i.state.wire,
        csvCell(i.currency),
        _amount(i.totalCents, i.currency),
        _amount(i.paidCents, i.currency),
        _amount(i.remainingCents, i.currency),
        '${i.reminderCount}',
        csvCell(i.id),
        'invoice',
        csvCell(overview.sourceOf(i.workspaceId).name),
        ..._blank(3),
      ].join(','),
    if (payments != null)
      for (final p in FinanceOverview.newestFirst(payments.payments))
        _paymentRow(p, payments.source.name),
    for (final source in notes)
      [
        csvCell(_noteMarker),
        csvCell(source),
        for (var c = 2; c < _columns.length; c++) '',
      ].join(','),
  ];
  return Uint8List.fromList(utf8.encode('${lines.join('\r\n')}\r\n'));
}

/// The file's name: the workspace and the day it was made.
String ownFinanceCsvName(String workspaceName, DateTime now) =>
    'deskilo-my-documents-${safeFileSlug(workspaceName)}-${isoDay(now)}.csv';
