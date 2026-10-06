// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #957 — one download per fiscal year: every invoice as PDF/A-3 with its
// embedded e-invoice, the invoice register, the FEC and the audit trail.
// Each piece existed on its own; retention under art. L102 B LPF is
// easier to demonstrate as one bundle named after the entity and the
// year — and marked DEV for a development workspace, which is never the
// real books.
import '../../../core/i18n/currencies.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'invoice.dart';

/// `<SIREN>-<year>-archive.zip`, `DEV-` first for a development workspace.
String archiveBundleFileName(String legalId, int year, {bool development = false}) {
  final siren = legalId.replaceAll(RegExp('[^0-9]'), '');
  return '${development ? 'DEV-' : ''}${siren.isEmpty ? 'archive' : siren}-$year-archive.zip';
}

/// The invoice register of one year: what an auditor reads first. One
/// line per document in issue order; the integrity word comes from
/// `verify_invoice_signature` (#956) when the caller fetched it.
String buildInvoiceRegisterCsv(
  List<Invoice> invoices, {
  Map<String, String> integrity = const {},
}) {
  String q(String v) => '"${v.replaceAll('"', '""')}"';
  // #1077 — the document's own currency decides the grain.
  String money(int minor, String code) => Currencies.toMajor(minor, code)
      .toStringAsFixed(Currencies.minorDigits(code));
  final rows = <String>[
    ['number', 'issued', 'period', 'kind', 'member', 'member_number', 'total', 'currency', 'status', 'replaces', 'integrity'].join(';'),
    for (final i in [...invoices]..sort((a, b) => a.issuedAt.compareTo(b.issuedAt)))
      [
        q(i.number),
        i.issuedAt.toIso8601String().substring(0, 10),
        q(i.period ?? ''),
        i.kind.name,
        q(i.memberName),
        q(i.buyerParty?.memberNumber ?? ''),
        money(i.totalCents, i.currency),
        i.currency,
        i.isVoided ? 'voided' : (i.isCreditNote ? 'credit_note' : 'issued'),
        q(i.replacesNumber),
        integrity[i.id] ?? '',
      ].join(';'),
  ];
  return '${rows.join('\r\n')}\r\n';
}

/// #1885 — every entry of an export archive carries this time, so the same
/// frozen input is the same bytes whenever and wherever it is zipped. The
/// encoder reads it as local wall-clock time, hence a local-constructed
/// date: its DOS fields come out the same in every timezone.
int get kZipEntryTime => DateTime(2000).millisecondsSinceEpoch ~/ 1000;

/// The zip: paths as given, bytes as given. Deterministic order so two
/// bundles of the same year are byte-identical.
Uint8List zipBundle(Map<String, List<int>> files) {
  final archive = Archive();
  for (final path in files.keys.toList()..sort()) {
    final bytes = files[path]!;
    archive.addFile(ArchiveFile(path, bytes.length, bytes)..lastModTime = kZipEntryTime);
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// The text files of a bundle, UTF-8 with a BOM-free header the
/// accountant's tools read.
List<int> textBytes(String text) => utf8.encode(text);
