// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3853 — the originals of the invoices on the server (0772): the PDF is
// uploaded once to the invoice-originals bucket at the path its digest
// names, then recorded by store_invoice_original, which checks the XML
// against the invoice. An upload that meets "already there" is the same
// file, by its path, and goes on to be recorded.
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/paged_fetch.dart';
import '../../../core/data/pg_code.dart';
import '../domain/invoice_original.dart';

const String _bucket = 'invoice-originals';

class SupabaseInvoiceOriginalRepository implements InvoiceOriginalRepository {
  SupabaseInvoiceOriginalRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<InvoiceOriginal?> originalOf(
    String workspaceId,
    String invoiceId,
  ) async {
    final row = await _client
        .from('invoice_originals')
        .select(
          'invoice_id, path, pdf_bytes, pdf_sha256, xml_sha256, created_by_user, created_datetime',
        )
        .eq('workspace_id', workspaceId)
        .eq('invoice_id', invoiceId)
        .maybeSingle();
    return row == null ? null : InvoiceOriginal.fromRow(row);
  }

  @override
  Future<Set<String>> keptIn(String workspaceId) async {
    final rows = await fetchAllPages(
      table: 'invoice_originals',
      build: () => _client
          .from('invoice_originals')
          .select('invoice_id')
          .eq('workspace_id', workspaceId)
          .order('invoice_id', ascending: true),
    );
    return {for (final r in rows) r['invoice_id']! as String};
  }

  @override
  Future<Uint8List> pdfOf(InvoiceOriginal original) =>
      _client.storage.from(_bucket).download(original.path);

  @override
  Future<String> xmlOf(String workspaceId, InvoiceOriginal original) async {
    final row = await _client
        .from('invoice_originals')
        .select('xml')
        .eq('workspace_id', workspaceId)
        .eq('invoice_id', original.invoiceId)
        .single();
    return row['xml'] as String? ?? '';
  }

  @override
  Future<InvoiceOriginal> store({
    required String workspaceId,
    required String invoiceId,
    required Uint8List pdf,
    required String xml,
  }) async {
    final sha = pdfSha256OfBytes(pdf);
    try {
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            invoiceOriginalPath(workspaceId, invoiceId, sha),
            pdf,
            fileOptions: const FileOptions(contentType: 'application/pdf'),
          );
    } on StorageException catch (e, st) {
      // trace-exempt: each answer becomes a refusal or goes on below.
      switch (e.statusCode) {
        case '409':
          break; // the same file, by its path: record it
        case '413':
          Error.throwWithStackTrace(
            InvoiceOriginalRefused(InvoiceOriginalRefusal.tooLarge, e.message),
            st,
          );
        case '401' || '403':
          Error.throwWithStackTrace(
            InvoiceOriginalRefused(
              InvoiceOriginalRefusal.notAllowed,
              e.message,
            ),
            st,
          );
        default:
          rethrow;
      }
    }
    try {
      await _client.rpc<Object?>(
        'store_invoice_original',
        params: {'p_invoice_id': invoiceId, 'p_pdf_sha256': sha, 'p_xml': xml},
      );
    } on PostgrestException catch (e, st) {
      // trace-exempt: each answer becomes a refusal or the record kept.
      if (e.code != PgCode.uniqueViolation) {
        Error.throwWithStackTrace(
          InvoiceOriginalRefused(
            e.code == PgCode.insufficientPrivilege
                ? InvoiceOriginalRefusal.notAllowed
                : InvoiceOriginalRefusal.refused,
            e.message,
          ),
          st,
        );
      }
    }
    final kept = await originalOf(workspaceId, invoiceId);
    if (kept == null) {
      throw const InvoiceOriginalRefused(InvoiceOriginalRefusal.refused);
    }
    return kept;
  }
}
