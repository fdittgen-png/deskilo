// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3853 — an issued invoice is its stored original: its PDF, kept once in
// the invoice-originals bucket at the path its digest names, and the record
// beside it (0772). Every later view, download or reprint serves those bytes,
// checked against the digest recorded when they were stored.
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The record of an invoice's stored original.
class InvoiceOriginal {
  const InvoiceOriginal({
    required this.invoiceId,
    required this.path,
    required this.pdfBytes,
    required this.pdfSha256,
    required this.xmlSha256,
    this.storedBy,
    this.storedAt,
  });

  factory InvoiceOriginal.fromRow(Map<String, Object?> row) => InvoiceOriginal(
    invoiceId: row['invoice_id']! as String,
    path: row['path']! as String,
    pdfBytes: (row['pdf_bytes']! as num).toInt(),
    pdfSha256: row['pdf_sha256']! as String,
    xmlSha256: row['xml_sha256']! as String,
    storedBy: row['created_by_user'] as String?,
    storedAt: switch (row['created_datetime']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
  );

  final String invoiceId;

  /// The PDF's object in the invoice-originals bucket.
  final String path;
  final int pdfBytes;

  /// The PDF's SHA-256 as it was stored; every read checks the bytes by it.
  final String pdfSha256;
  final String xmlSha256;

  /// Who stored it (the account) and when.
  final String? storedBy;
  final DateTime? storedAt;

  /// Whether [pdf] is the PDF that was stored.
  bool holds(Uint8List pdf) => pdfSha256OfBytes(pdf) == pdfSha256;

  /// #4120 — whether [xml] is the structured part that was stored with it,
  /// by the digest the server computed of its UTF-8 bytes.
  bool holdsXml(String xml) => pdfSha256OfBytes(utf8.encode(xml)) == xmlSha256;
}

/// The hex SHA-256 of [pdf], as the original's record names it.
String pdfSha256OfBytes(List<int> pdf) => sha256.convert(pdf).toString();

/// The object path of an invoice's original: its business's folder, the
/// invoice's, and the PDF's digest (0772).
String invoiceOriginalPath(
  String workspaceId,
  String invoiceId,
  String pdfSha256,
) => '$workspaceId/$invoiceId/$pdfSha256.pdf';

/// Why an original was not kept.
enum InvoiceOriginalRefusal {
  /// The PDF is larger than the store keeps (the bucket's own limit).
  tooLarge,

  /// The caller may not store originals in this business.
  notAllowed,

  /// The server refused the record: its words are in the message.
  refused,
}

class InvoiceOriginalRefused implements Exception {
  const InvoiceOriginalRefused(this.reason, [this.message = '']);

  final InvoiceOriginalRefusal reason;
  final String message;

  @override
  String toString() => 'InvoiceOriginalRefused(${reason.name}: $message)';
}

/// Where the originals of the invoices are kept.
abstract interface class InvoiceOriginalRepository {
  /// The record of the original of the invoice [invoiceId] of
  /// [workspaceId], or null when none is kept.
  Future<InvoiceOriginal?> originalOf(String workspaceId, String invoiceId);

  /// The invoices of [workspaceId] whose original is kept.
  Future<Set<String>> keptIn(String workspaceId);

  /// The stored PDF of [original], as it is held.
  Future<Uint8List> pdfOf(InvoiceOriginal original);

  /// #4120 — the structured part (CII) stored with [original] in
  /// [workspaceId], as it is held.
  Future<String> xmlOf(String workspaceId, InvoiceOriginal original);

  /// Stores [pdf] as the original of the invoice [invoiceId] of [workspaceId],
  /// with its CII [xml]; the server checks the XML against the invoice.
  /// Throws [InvoiceOriginalRefused] when it is not kept.
  Future<InvoiceOriginal> store({
    required String workspaceId,
    required String invoiceId,
    required Uint8List pdf,
    required String xml,
  });
}
