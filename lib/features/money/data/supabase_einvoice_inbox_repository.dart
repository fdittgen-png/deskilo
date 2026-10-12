// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/einvoice_inbox.dart';
import '../domain/inbound_einvoice.dart';

/// #2358 — the inbox table and its three RPCs (0415).
class SupabaseEInvoiceInboxRepository implements EInvoiceInboxRepository {
  const SupabaseEInvoiceInboxRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<InboxDocument>> fetchInbox(String workspaceId) async {
    final rows = await _client
        .from('einvoice_inbox')
        .select(
          'id, invoice_number, issue_date, currency, supplier_name, '
          'gross_cents, status, document_type, reject_reason',
        )
        .eq('workspace_id', workspaceId)
        .order('issue_date', ascending: false)
        .limit(100);
    return [for (final r in rows) InboxDocument.fromRow(r)];
  }

  @override
  Future<void> ingest(
    String workspaceId,
    String xml,
    InboundEInvoice parsed,
  ) async {
    await _client.rpc<Object?>(
      'ingest_einvoice',
      params: {
        'p_workspace_id': workspaceId,
        'p_syntax': parsed.syntax.name,
        'p_xml': xml,
        'p_parsed': parsed.toRpc(),
      },
    );
  }

  @override
  Future<List<InboxCandidate>> candidates(String documentId) async {
    final rows = await _client.rpc<List<Object?>>(
      'einvoice_match_candidates',
      params: {'p_inbox_id': documentId},
    );
    return [for (final r in rows) InboxCandidate.fromRow(r)];
  }

  @override
  Future<void> match(String documentId, String eventId) async {
    await _client.rpc<Object?>(
      'match_einvoice',
      params: {'p_inbox_id': documentId, 'p_event_id': eventId},
    );
  }

  @override
  Future<void> reject(String documentId, String reason) async {
    await _client.rpc<Object?>(
      'reject_einvoice',
      params: {'p_inbox_id': documentId, 'p_reason': reason},
    );
  }
}
