// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/bank/bank_records.dart';
import '../domain/bank/bank_statement.dart';

/// The bank statements (`bank_statements`, `bank_statement_lines`) through
/// their RPCs. Every call checks the bankImport flag and the caller's
/// right on the server.
class SupabaseBankStatementRepository implements BankStatementRepository {
  const SupabaseBankStatementRepository(this._client);

  final SupabaseClient _client;

  Future<BankLineStatus> _status(String fn, Map<String, Object?> params) async {
    final row = await _client.rpc<Object?>(fn, params: params);
    return BankLineStatus.fromWire(
      row is Map ? row['status'] as String? : null,
    );
  }

  @override
  Future<List<StoredBankStatement>> fetchStatements(String workspaceId) async {
    final rows = await _client.rpc<Object?>(
      'bank_statements_v1',
      params: {'p_workspace_id': workspaceId},
    );
    return [
      for (final row in rows is List ? rows : const <Object?>[])
        StoredBankStatement.fromJson(row),
    ];
  }

  @override
  Future<List<StoredBankLine>> fetchLines(String statementId) async {
    final rows = await _client.rpc<Object?>(
      'bank_statement_lines_v1',
      params: {'p_statement_id': statementId},
    );
    return [
      for (final row in rows is List ? rows : const <Object?>[])
        StoredBankLine.fromJson(row),
    ];
  }

  /// #2380 — the bucket of the originals (0621); the path is
  /// `<workspace_id>/<sha256>`, as its storage policies require.
  static const _originals = 'bank-statements';

  @override
  Future<void> storeOriginal(
    String workspaceId, {
    required String sourceSha256,
    required List<int> bytes,
  }) async {
    try {
      await _client.storage.from(_originals).uploadBinary(
            '$workspaceId/$sourceSha256',
            Uint8List.fromList(bytes),
            fileOptions: const FileOptions(
              contentType: 'application/octet-stream',
            ),
          );
    } on StorageException catch (e) {
      // The same digest is the same file: kept already (a repeated import,
      // or one whose import failed after its upload).
      if (e.statusCode != '409' && !e.message.contains('exists')) rethrow;
    }
  }

  @override
  Future<Uint8List> fetchOriginal(String workspaceId, String sourceSha256) =>
      _client.storage.from(_originals).download('$workspaceId/$sourceSha256');

  @override
  Future<BankImportResult> importStatement(
    String workspaceId, {
    required BankStatement statement,
    required String sourceSha256,
    required String fileName,
  }) async => BankImportResult.fromJson(
    await _client.rpc<Object?>(
      'import_bank_statement_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_statement': {
          'format': statement.format.name,
          'account': statement.account,
          'currency': statement.currency,
          'statement_ref': statement.statementId,
          'source_sha256': sourceSha256,
          'file_name': fileName,
          'opening_cents': statement.openingCents,
          'closing_cents': statement.closingCents,
        },
        'p_lines': [for (final l in statement.lines) l.toJson()],
      },
    ),
  );

  @override
  Future<BankLineStatus> matchLine(
    String lineId, {
    required String invoiceId,
    required String resolution,
    required String note,
  }) => _status('match_bank_line_v1', {
    'p_line_id': lineId,
    'p_invoice_id': invoiceId,
    'p_resolution': resolution,
    'p_note': note,
  });

  @override
  Future<BankLineStatus> reviewLine(String lineId, {required bool duplicate}) =>
      _status('review_bank_line_v1', {
        'p_line_id': lineId,
        'p_duplicate': duplicate,
      });

  @override
  Future<BankLineStatus> reconcileOut(
    String lineId, {
    required String outgoingPaymentId,
  }) => _status('reconcile_bank_line_out_v1', {
    'p_line_id': lineId,
    'p_outgoing_payment_id': outgoingPaymentId,
  });
}
