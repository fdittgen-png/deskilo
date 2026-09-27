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

import 'accountant_csv.dart';
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

  /// Nothing blocking: the file may be handed over as it is.
  bool get clean => !findings.any((f) => f.blocking);

  Map<String, Object?> toJson() => {
    'format': 'deskilo-accountant-csv',
    'format_version': accountantCsvFormatVersion,
    'encoding': 'UTF-8',
    'delimiter': ',',
    'columns': accountantCsvColumns,
    'generated_at': generatedAt.toUtc().toIso8601String(),
    'included': included,
    'excluded': excluded,
    'totals': {
      for (final c in totals.entries)
        c.key: {for (final l in c.value.entries) l.key: l.value.toJson()},
    },
    'payments': {for (final p in payments.entries) p.key: p.value.toJson()},
    'findings': [for (final f in findings) f.toJson()],
    'clean': clean,
    'file': {'sha256': csvSha256, 'bytes': csvBytes, 'rows': csvRows},
    'note':
        'Documents as issued; not a journal, no account mapping, no '
        'opening balance. Totals are per currency and never added across '
        'currencies.',
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// The data rows of an emitted accountant CSV: `#` preamble lines and
/// the header skipped, quoted fields (with doubled quotes and embedded
/// delimiters) honoured. Used to check the bytes, not to build them.
List<List<String>> parseAccountantCsvRows(String csv) {
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
/// [invoices] and [matches].
AccountantHandoff buildAccountantHandoff({
  required List<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
  required String csv,
  required DateTime generatedAt,
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
    final t = totals
        .putIfAbsent(currency, () => {})
        .putIfAbsent(invoice.isVoided ? 'voided' : 'issued', HandoffTotals.new);
    t.count++;
    t.netMinor += invoice.netCents;
    t.vatMinor += invoice.vatCents;
    t.grossMinor += accountantGrossCents(invoice);

    final match = matches[invoice.id];
    if (match == null) continue;
    final p = payments.putIfAbsent(currency, HandoffPayments.new);
    if (match.pending) {
      p.pendingMinor += match.paidCents;
      p.pendingCount++;
    } else {
      p.confirmedMinor += match.paidCents;
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

  final rows = parseAccountantCsvRows(csv).length;
  if (rows != included) {
    findings.add(
      HandoffFinding(HandoffFindingKind.rowCountMismatch, '$rows != $included'),
    );
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
  );
}

/// #1640 — a fingerprint of what the export was built from: each
/// document's identity, amounts, currency, lifecycle and settlement, and
/// each payment match's amount, status and date, independent of order.
/// Read again just before saving; a different fingerprint means the
/// source changed while the owner was reviewing, and nothing is saved.
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
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
  add(csvName, utf8.encode(csv));
  add('report.json', utf8.encode(report.toPrettyJson()));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
