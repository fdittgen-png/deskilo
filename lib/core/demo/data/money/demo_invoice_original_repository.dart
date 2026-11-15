// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3853 — the Demo's stored originals, in memory: written once per invoice
// like the server's, at the path the PDF's digest names, and read back as
// stored. An invoice issued in the Demo keeps its original from its first
// render on, so the Demo shows the same original whoever opens it.
import 'dart:convert';
import 'dart:typed_data';

import '../../../../features/money/domain/invoice_original.dart';

class DemoInvoiceOriginalRepository implements InvoiceOriginalRepository {
  DemoInvoiceOriginalRepository({required this.storedBy, required this.now});

  /// The account that stores an original, and the instant it does.
  final String? Function() storedBy;
  final DateTime Function() now;

  final Map<String, InvoiceOriginal> _records = {};
  final Map<String, Uint8List> _files = {};

  @override
  Future<InvoiceOriginal?> originalOf(String invoiceId) async =>
      _records[invoiceId];

  @override
  Future<Uint8List> pdfOf(InvoiceOriginal original) async =>
      _files[original.path] ?? Uint8List(0);

  @override
  Future<InvoiceOriginal> store({
    required String workspaceId,
    required String invoiceId,
    required Uint8List pdf,
    required String xml,
  }) async {
    final kept = _records[invoiceId];
    if (kept != null) return kept;
    final sha = pdfSha256OfBytes(pdf);
    final path = invoiceOriginalPath(workspaceId, invoiceId, sha);
    _files[path] = Uint8List.fromList(pdf);
    return _records[invoiceId] = InvoiceOriginal(
      invoiceId: invoiceId,
      path: path,
      pdfBytes: pdf.length,
      pdfSha256: sha,
      xmlSha256: pdfSha256OfBytes(utf8.encode(xml)),
      storedBy: storedBy(),
      storedAt: now(),
    );
  }
}
