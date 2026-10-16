// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/invoice_pdf_template.dart';
import '../domain/report_template_repository.dart';
import 'report_image_read.dart';

/// #2591 C2 — the report template and image library, with their own
/// client. The bodies are the ones that lived in the money repository's
/// part file.
class SupabaseReportTemplateRepository implements ReportTemplateRepository {
  SupabaseReportTemplateRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<InvoicePdfTemplate> fetchInvoicePdfTemplate(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('invoice_pdf_template')
        .eq('id', workspaceId)
        .single();
    return InvoicePdfTemplate.fromJson(
      row['invoice_pdf_template'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  Future<void> setInvoicePdfTemplate(
    String workspaceId,
    InvoicePdfTemplate template,
  ) async {
    // #982 — through the matrix (designDocuments), not the owner-only
    // row update.
    await _client.rpc<dynamic>(
      'set_invoice_pdf_template',
      params: {'p_workspace_id': workspaceId, 'p_template': template.toJson()},
    );
  }

  @override
  Future<List<String>> listReportImages(String workspaceId) async {
    // #488 — the report-image library lives beside the level backgrounds
    // in the private floor-plans bucket; the 0036 RLS (first path
    // segment = workspace) covers it member-read / owner-write.
    final entries = await _client.storage
        .from('floor-plans')
        .list(path: '$workspaceId/report');
    return [
      for (final entry in entries)
        if (entry.name.isNotEmpty) entry.name,
    ]..sort();
  }

  @override
  Future<void> uploadReportImage(
    String workspaceId, {
    required String name,
    required List<int> bytes,
    required String contentType,
  }) async {
    await _client.storage
        .from('floor-plans')
        .uploadBinary(
          '$workspaceId/report/$name',
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
  }

  @override
  Future<Uint8List?> fetchReportImage(String workspaceId, String name) =>
      readReportImage(
        name,
        () => _client.storage
            .from('floor-plans')
            .download('$workspaceId/report/$name'),
      );
}
