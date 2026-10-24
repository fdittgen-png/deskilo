// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C3 — Me › Finances: my own documents of ONE workspace as a CSV
// file, as the overview read them from that workspace's host. One file per
// workspace: currencies are never summed together and no total is
// invented. Text cells go through the shared cell writer (quoting, line
// breaks and formula injection); amounts are numbers in the currency's own
// exponent, never a universal /100; the document state is the server's.
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/files/file_names.dart';
import '../../../core/i18n/currencies.dart';
import '../../../core/text/csv.dart';
import '../../../core/time/date_text.dart';
import 'finance_overview.dart';

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
];

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

/// The invoices of [overview], newest first (the id breaks a tie), as CSV
/// rows under [_columns]; UTF-8, CRLF line ends. When a host did not
/// answer, one note row per such host follows the documents — the marker
/// and the host, both through [csvCell] — so the file itself says it holds
/// only what the other hosts returned.
Uint8List ownFinanceCsv(FinanceOverview overview) {
  final invoices = [...overview.invoices]
    ..sort((a, b) {
      final byDate = b.issuedAt.compareTo(a.issuedAt);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
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
      ].join(','),
    for (final source in overview.unavailableSources)
      [
        csvCell(_noteMarker),
        csvCell(_host(source)),
        for (var c = 2; c < _columns.length; c++) '',
      ].join(','),
  ];
  return Uint8List.fromList(utf8.encode('${lines.join('\r\n')}\r\n'));
}

/// The file's name: the workspace and the day it was made.
String ownFinanceCsvName(String workspaceName, DateTime now) =>
    'deskilo-my-documents-${safeFileSlug(workspaceName)}-${isoDay(now)}.csv';
