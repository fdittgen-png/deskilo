// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1640 — what goes to the accountant beside the plain CSV: a small
// report of what the file holds, what it left out and why, the totals
// per currency and lifecycle, confirmed against pending payments, and
// what disagrees in the source. It describes the documents as issued;
// it reconstructs no journal and invents no opening balance.
//
// Every amount is an integer in the document's own minor unit, and each
// currency keeps its own totals: two currencies are never added into
// one number.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import '../../../core/time/date_text.dart';
import 'accountant_csv.dart';
import 'accounting_connection.dart';
import 'accounting_amount.dart';
import 'archive_bundle.dart' show kZipEntryTime;
import 'billing_rules.dart';
import 'invoice.dart';

/// A sum of documents in one currency and one lifecycle.
class HandoffTotals {
  int count = 0;
  int netMinor = 0;
  int vatMinor = 0;
  int grossMinor = 0;

  Map<String, int> toJson() => {
    'count': count,
    'net_minor': netMinor,
    'vat_minor': vatMinor,
    'gross_minor': grossMinor,
  };
}

/// Payments in one currency, confirmed apart from pending.
class HandoffPayments {
  int confirmedMinor = 0;
  int pendingMinor = 0;
  int confirmedCount = 0;
  int pendingCount = 0;

  Map<String, int> toJson() => {
    'confirmed_minor': confirmedMinor,
    'confirmed_count': confirmedCount,
    'pending_minor': pendingMinor,
    'pending_count': pendingCount,
  };
}

enum HandoffFindingKind {
  /// A document with no currency: its amounts mean nothing. Blocking.
  missingCurrency,

  /// The same document (id or number) twice in the source. Blocking.
  duplicateDocument,

  /// A payment match for no document of this export, or filed under
  /// another document's id — another space's data, or a broken read.
  /// Blocking.
  orphanMatch,

  /// The file's rows are not the documents the report counted. Blocking.
  rowCountMismatch,

  /// Confirmed payment above what the document charges. Shown, not
  /// repaired.
  overpaid,

  /// #1870 — a currency with no reviewed exponent: its minor units
  /// cannot be read without guessing. Blocking.
  unsupportedCurrency,

  /// #1870 — a total that would pass ±(2^53 − 1) minor units, the most
  /// a JSON reader keeps exactly. Blocking.
  amountOutOfRange,
}

class HandoffFinding {
  const HandoffFinding(this.kind, this.subject);
  final HandoffFindingKind kind;

  /// The document number (or match key) the finding is about.
  final String subject;

  bool get blocking => kind != HandoffFindingKind.overpaid;

  Map<String, Object> toJson() => {
    'kind': kind.name,
    'subject': subject,
    'blocking': blocking,
  };
}

class AccountantHandoff {
  AccountantHandoff._({
    required this.generatedAt,
    required this.included,
    required this.excluded,
    required this.totals,
    required this.payments,
    required this.findings,
    required this.csvSha256,
    required this.csvBytes,
    required this.csvRows,
    required this.columns,
    required this.transfers,
  });

  final DateTime generatedAt;

  /// Documents written as rows.
  final int included;

  /// Documents loaded but not written, by reason.
  final Map<String, int> excluded;

  /// currency → lifecycle (`issued` / `voided`) → totals.
  final Map<String, Map<String, HandoffTotals>> totals;

  /// currency → payments of the included documents.
  final Map<String, HandoffPayments> payments;

  final List<HandoffFinding> findings;
  final String csvSha256;
  final int csvBytes;

  /// Data rows the emitted file actually holds, parsed back.
  final int csvRows;

  /// #2378 — the header of the emitted file: the fixed columns and the tax
  /// key columns of the period, as written.
  final List<String> columns;

  /// #2378 — what the Transfers list holds for the period: every file handed
  /// out with its digest and the documents it carried, and every document
  /// delivered to a connection. Null when the space keeps no Transfers list
  /// (the accounting systems are off); the report then quotes none.
  final AccountingTransfers? transfers;

  /// Nothing blocking: the file may be handed over as it is.
  bool get clean => !findings.any((f) => f.blocking);

  Map<String, Object?> toJson() => {
    'format': 'deskilo-accountant-csv',
    'format_version': accountantCsvFormatVersion,
    'encoding': 'UTF-8',
    'delimiter': ',',
    'columns': columns,
    'generated_at': generatedAt.toUtc().toIso8601String(),
    'included': included,
    // #1885 — keys in a fixed order, so the same books read in another
    // order give the same bytes (the CSV is ordered; its report must be).
    'excluded': {for (final k in excluded.keys.toList()..sort()) k: excluded[k]},
    'totals': {
      for (final c in totals.keys.toList()..sort())
        c: {
          for (final l in totals[c]!.keys.toList()..sort())
            l: totals[c]![l]!.toJson(),
        },
    },
    'payments': {
      for (final c in payments.keys.toList()..sort()) c: payments[c]!.toJson(),
    },
    'findings': [for (final f in findings) f.toJson()],
    'clean': clean,
    'file': {'sha256': csvSha256, 'bytes': csvBytes, 'rows': csvRows},
    if (transfers case final t?) 'transfers': _transfersJson(t),
    'note':
        'Documents as issued; not a journal, no account mapping, no '
        'opening balance. Totals are per currency and never added across '
        'currencies.',
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// One document event as the report quotes it.
Map<String, Object> _deliveryJson(AccountingDelivery d) => {
  'document_kind': d.documentKind,
  'document_number': d.documentNumber,
  'event_date': isoDay(d.eventDate),
  'sha256': d.payloadSha256,
};

/// [t] in a fixed order, so the same transfers give the same bytes: files
/// by when they were made, deliveries by day and document.
Map<String, Object> _transfersJson(AccountingTransfers t) {
  int byDocument(AccountingDelivery a, AccountingDelivery b) {
    final day = a.eventDate.compareTo(b.eventDate);
    if (day != 0) return day;
    final number = a.documentNumber.compareTo(b.documentNumber);
    return number != 0 ? number : a.id.compareTo(b.id);
  }

  final files = [...t.files]..sort((a, b) {
    final at = a.exportedAt.compareTo(b.exportedAt);
    return at != 0 ? at : a.id.compareTo(b.id);
  });
  return {
    'files': [
      for (final f in files)
        {
          'format_id': f.formatId,
          'period_from': isoDay(f.from),
          'period_to': isoDay(f.to),
          'exported_at': f.exportedAt.toUtc().toIso8601String(),
          'sha256': f.sha256,
          'document_count': f.documentCount,
          'documents': [
            for (final d in [...f.deliveries]..sort(byDocument)) _deliveryJson(d),
          ],
        },
    ],
    'deliveries': [
      for (final d in [...t.deliveries]..sort(byDocument))
        {
          'target_id': d.targetId,
          ..._deliveryJson(d),
          'status': d.status.wire,
          'remote_number': d.remoteNumber.isNotEmpty ? d.remoteNumber : d.remoteId,
        },
    ],
  };
}

/// The data rows of an emitted accountant CSV: `#` preamble lines and
/// the header skipped, quoted fields (with doubled quotes and embedded
/// delimiters) honoured. Used to check the bytes, not to build them.
List<List<String>> _parseAccountantCsvRows(String csv) {
  final rows = <List<String>>[];
  final lines = const LineSplitter().convert(csv);
  var headerSeen = false;
  for (final line in lines) {
    if (line.isEmpty || line.startsWith('#')) continue;
    if (!headerSeen) {
      headerSeen = true;
      continue;
    }
    final cells = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (quoted) {
        if (ch == '"' && i + 1 < line.length && line[i + 1] == '"') {
          cell.write('"');
          i++;
        } else if (ch == '"') {
          quoted = false;
        } else {
          cell.write(ch);
        }
      } else if (ch == '"') {
        quoted = true;
      } else if (ch == ',') {
        cells.add(cell.toString());
        cell.clear();
      } else {
        cell.write(ch);
      }
    }
    cells.add(cell.toString());
    rows.add(cells);
  }
  return rows;
}

/// The report for [csv], which [buildAccountantCsv] made from the same
/// [invoices] and [matches]; it quotes [transfers] when the space keeps a
/// Transfers list.
AccountantHandoff buildAccountantHandoff({
  required List<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
  required String csv,
  required DateTime generatedAt,
  AccountingTransfers? transfers,
}) {
  final findings = <HandoffFinding>[];
  final excluded = <String, int>{};
  final totals = <String, Map<String, HandoffTotals>>{};
  final payments = <String, HandoffPayments>{};
  final seenIds = <String>{};
  final seenNumbers = <String>{};
  final byId = {for (final i in invoices) i.id: i};
  var included = 0;

  for (final invoice in invoices) {
    if (!seenIds.add(invoice.id)) {
      findings.add(
        HandoffFinding(HandoffFindingKind.duplicateDocument, invoice.number),
      );
      continue;
    }
    if (invoice.kind == InvoiceKind.settlement) {
      excluded.update('settlement_summary', (n) => n + 1, ifAbsent: () => 1);
      continue;
    }
    if (!seenNumbers.add(invoice.number)) {
      findings.add(
        HandoffFinding(HandoffFindingKind.duplicateDocument, invoice.number),
      );
    }
    included++;
    final currency = invoice.currency.trim();
    if (currency.isEmpty) {
      findings.add(
        HandoffFinding(HandoffFindingKind.missingCurrency, invoice.number),
      );
      continue;
    }
    // #1870 — the totals add through the exact amount: an unreviewed
    // currency is refused rather than read as two decimals, and a sum
    // that leaves the exact range is refused rather than wrapped.
    int add(int a, int b) =>
        (AccountingAmount(currency, a) + AccountingAmount(currency, b)).minor;
    try {
      exponentOf(currency);
    } on AccountingException {
      findings.add(
        HandoffFinding(HandoffFindingKind.unsupportedCurrency, invoice.number),
      );
      continue;
    }
    final t = totals
        .putIfAbsent(currency, () => {})
        .putIfAbsent(invoice.isVoided ? 'voided' : 'issued', HandoffTotals.new);
    try {
      final net = add(t.netMinor, invoice.netCents);
      final vat = add(t.vatMinor, invoice.vatCents);
      final gross = add(t.grossMinor, accountantGrossCents(invoice));
      t
        ..count += 1
        ..netMinor = net
        ..vatMinor = vat
        ..grossMinor = gross;
    } on AccountingException {
      findings.add(
        HandoffFinding(HandoffFindingKind.amountOutOfRange, invoice.number),
      );
      continue;
    }

    final match = matches[invoice.id];
    if (match == null) continue;
    final p = payments.putIfAbsent(currency, HandoffPayments.new);
    try {
      if (match.pending) {
        p.pendingMinor = add(p.pendingMinor, match.paidCents);
      } else {
        p.confirmedMinor = add(p.confirmedMinor, match.paidCents);
      }
    } on AccountingException {
      findings.add(
        HandoffFinding(HandoffFindingKind.amountOutOfRange, invoice.number),
      );
      continue;
    }
    if (match.pending) {
      p.pendingCount++;
    } else {
      p.confirmedCount++;
      if (invoice.chargesCents > 0 && match.paidCents > invoice.chargesCents) {
        findings.add(
          HandoffFinding(HandoffFindingKind.overpaid, invoice.number),
        );
      }
    }
  }

  for (final entry in matches.entries) {
    if (!byId.containsKey(entry.key) || entry.value.invoiceId != entry.key) {
      findings.add(HandoffFinding(HandoffFindingKind.orphanMatch, entry.key));
    }
  }

  final rows = _parseAccountantCsvRows(csv).length;
  if (rows != included) {
    findings.add(HandoffFinding(
        HandoffFindingKind.rowCountMismatch, '$rows != $included'));
  }
  final bytes = utf8.encode(csv);
  return AccountantHandoff._(
    generatedAt: generatedAt,
    included: included,
    excluded: excluded,
    totals: totals,
    payments: payments,
    findings: findings,
    csvSha256: sha256.convert(bytes).toString(),
    csvBytes: bytes.length,
    csvRows: rows,
    columns: _accountantCsvHeader(csv),
    transfers: transfers,
  );
}

/// #2378 — the header line of an emitted accountant CSV, split: its names
/// are never quoted ([accountantTaxKey] keeps them plain).
List<String> _accountantCsvHeader(String csv) {
  for (final line in const LineSplitter().convert(csv)) {
    if (line.isEmpty || line.startsWith('#')) continue;
    return line.split(',');
  }
  return const [];
}

/// #2365 — [accountantSourceDigest] of the documents in [kept] only: an
/// export's matches are its one source's, so another year's never count on
/// either side of the recheck.
String accountantScopeDigest(
  Iterable<Invoice> invoices,
  Map<String, InvoiceMatch> matches,
  Set<String> kept,
) => accountantSourceDigest(
  [
    for (final i in invoices)
      if (kept.contains(i.id)) i,
  ],
  {
    for (final e in matches.entries)
      if (kept.contains(e.key)) e.key: e.value,
  },
);

/// #1640 — a fingerprint of what the export was built from: each
/// document's identity, amounts, currency, lifecycle and settlement, and
/// each payment match's amount, status and date, independent of order.
/// Read again just before saving; a different fingerprint means the
/// source changed while the owner was reviewing, and nothing is saved.
@visibleForTesting
String accountantSourceDigest(
  List<Invoice> invoices,
  Map<String, InvoiceMatch> matches,
) {
  final rows = [
    for (final i in invoices)
      [
        'i',
        i.id,
        i.number,
        i.currency,
        i.kind.name,
        i.totalCents,
        i.chargesCents,
        i.vatCents,
        i.voidedAt?.toUtc().toIso8601String() ?? '',
        i.settledByInvoiceId ?? '',
      ].join('|'),
    for (final e in matches.entries)
      [
        'm',
        e.key,
        e.value.invoiceId,
        e.value.paidCents,
        e.value.status,
        e.value.matchedAt.toUtc().toIso8601String(),
        e.value.writeoffAt?.toUtc().toIso8601String() ?? '',
      ].join('|'),
  ]..sort();
  return sha256.convert(utf8.encode(rows.join('\n'))).toString();
}

/// #1640 — the file and its report as ONE archive, so they cannot be
/// separated on the way to the accountant: [csvName] and `report.json`,
/// whose `file.sha256` names the CSV's bytes exactly.
Uint8List accountantHandoffArchive({
  required String csv,
  required String csvName,
  required AccountantHandoff report,
}) {
  final archive = Archive();
  void add(String path, List<int> bytes) =>
      archive.addFile(
          ArchiveFile(path, bytes.length, bytes)..lastModTime = kZipEntryTime);
  add(csvName, utf8.encode(csv));
  add('report.json', utf8.encode(report.toPrettyJson()));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
