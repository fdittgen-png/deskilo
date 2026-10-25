// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/document_numbering.dart';
import '../domain/number_sequence.dart';

/// #2591 — the number series and the invoice fingerprint check, with its own
/// client. The bodies are the ones that lived in the money repository and its
/// part files.
class SupabaseDocumentNumbering implements DocumentNumbering {
  SupabaseDocumentNumbering(this._client);

  final SupabaseClient _client;

  @override
  Future<List<NumberSequence>> fetchNumberSequences(String workspaceId) async {
    final rows = await _client
        .from('number_sequences')
        .select()
        .eq('workspace_id', workspaceId)
        .order('journal');
    final byJournal = {
      for (final r in rows) r['journal'] as String: NumberSequence.fromDb(r),
    };
    // Every journal the app knows is listed, seeded or not: the screen
    // shows the default a lazy row would take, so a series that was
    // never touched is still visible beside the ones that were.
    return [
      for (final j in NumberSequence.journals)
        byJournal[j] ?? NumberSequence.defaultsFor(j),
    ];
  }

  @override
  Future<String> previewDocumentNumber(
    String workspaceId,
    String journal,
  ) async {
    final r = await _client.rpc<dynamic>(
      'preview_document_number',
      params: {'p_workspace_id': workspaceId, 'p_journal': journal},
    );
    return r as String;
  }

  @override
  Future<String> verifyInvoiceSignature(String invoiceId) async {
    final r = await _client.rpc<dynamic>(
      'verify_invoice_signature',
      params: {'p_invoice_id': invoiceId},
    );
    return r as String? ?? 'unverifiable';
  }

  @override
  Future<void> setNumberSequence(
    String workspaceId,
    NumberSequence sequence, {
    int? raiseNextValueTo,
  }) async {
    await _client.rpc<dynamic>(
      'set_number_sequence',
      params: {
        'p_workspace_id': workspaceId,
        'p_journal': sequence.journal,
        'p_prefix': sequence.prefix,
        'p_suffix': sequence.suffix,
        'p_date_part': NumberSequence.datePartWire(sequence.datePart),
        'p_digits': sequence.digits,
        'p_reset': NumberSequence.resetWire(sequence.reset),
        'p_next_value': ?raiseNextValueTo,
      },
    );
  }
}
