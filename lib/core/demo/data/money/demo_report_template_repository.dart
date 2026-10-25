// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/report_template_repository.dart';

import '../money_repository.dart';

/// #2591 — the demo's report template and the image library, answered from
/// one space's in-memory money store ([FakeMoneyRepository]); every other port
/// of that space reads and writes the same store.
class DemoReportTemplates implements ReportTemplateRepository {
  DemoReportTemplates(this._m);

  final FakeMoneyRepository _m;

  @override
  Future<InvoicePdfTemplate> fetchInvoicePdfTemplate(
    String workspaceId,
  ) async => _m.pdfTemplate;

  @override
  Future<void> setInvoicePdfTemplate(
    String workspaceId,
    InvoicePdfTemplate template,
  ) async {
    _m.pdfTemplate = template;
  }

  @override
  Future<List<String>> listReportImages(String workspaceId) async =>
      _m.reportImages.keys.toList()..sort();

  @override
  Future<void> uploadReportImage(
    String workspaceId, {
    required String name,
    required List<int> bytes,
    required String contentType,
  }) async {
    _m.reportImages[name] = bytes;
  }

  @override
  Future<Uint8List?> fetchReportImage(String workspaceId, String name) async =>
      _m.reportImages[name] == null
      ? null
      : Uint8List.fromList(_m.reportImages[name]!);
}
