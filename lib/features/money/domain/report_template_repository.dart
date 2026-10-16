// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'invoice_pdf_template.dart';

/// #2591 C2 — the report template and the image library it references:
/// what the preview, the editor and the PDF renderer read and what the
/// editor writes. Nothing here touches invoices, payments or VAT, so the
/// document-package extraction (#2592) consumes this and nothing wider.
abstract interface class ReportTemplateRepository {
  /// The workspace's invoice-PDF template (#454, 0088); empty when the
  /// column holds no keys.
  Future<InvoicePdfTemplate> fetchInvoicePdfTemplate(String workspaceId);

  /// Replaces the invoice-PDF template wholesale, through the
  /// `designDocuments` matrix on the server (#982).
  Future<void> setInvoicePdfTemplate(
    String workspaceId,
    InvoicePdfTemplate template,
  );

  /// The workspace's report-image library (#488): file names stored
  /// under `<workspace>/report/` in the floor-plans bucket — the logo,
  /// stamps, signature scans the templates reference with `![name]`.
  Future<List<String>> listReportImages(String workspaceId);

  /// Owner-only (bucket RLS): add or replace a library image.
  Future<void> uploadReportImage(
    String workspaceId, {
    required String name,
    required List<int> bytes,
    required String contentType,
  });

  /// Image bytes; null ONLY if absent, else a failed read throws (#2586).
  Future<Uint8List?> fetchReportImage(String workspaceId, String name);
}
