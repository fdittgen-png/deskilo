// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/time/date_text.dart';
import '../domain/accounting_connection.dart';
import '../domain/accounting_target.dart';

/// The accounting connections, mappings and transfers (0595) and the
/// `accounting-connect` function. Every read and write checks the flag and
/// the right on the server; no answer carries a secret.
class SupabaseAccountingConnectionRepository
    implements AccountingConnectionRepository {
  const SupabaseAccountingConnectionRepository(this._client);

  final SupabaseClient _client;

  /// The HTTP status `accounting-connect` answers when this installation
  /// registered no application with the target.
  static const _notConfigured = 503;

  Future<AccountingConnection> _connection(
    String fn,
    Map<String, Object?> params,
  ) async => AccountingConnection.fromJson(
    await _client.rpc<Object?>(fn, params: params),
  );

  @override
  Future<List<AccountingConnection>> fetchConnections(
    String workspaceId,
  ) async {
    final rows = await _client.rpc<Object?>(
      'accounting_connections_v1',
      params: {'p_workspace_id': workspaceId},
    );
    return [
      for (final row in rows is List ? rows : const <Object?>[])
        AccountingConnection.fromJson(row),
    ];
  }

  @override
  Future<AccountingConnection> openTokenConnection(
    String workspaceId, {
    required String issuerSiteId,
    required String targetId,
    required String displayName,
  }) => _connection('open_accounting_connection_v1', {
    'p_workspace_id': workspaceId,
    'p_issuer_site_id': issuerSiteId,
    'p_target_id': targetId,
    'p_auth_kind': AccountingAuthKind.token.wire,
    'p_display_name': displayName,
  });

  @override
  Future<AccountingConnection> setToken(
    String connectionId, {
    required String token,
    required String remoteTenantId,
  }) => _connection('set_accounting_token_v1', {
    'p_connection_id': connectionId,
    'p_token': token,
    'p_remote_tenant_id': remoteTenantId,
  });

  @override
  Future<SignInStart> startSignIn(
    String workspaceId, {
    required String issuerSiteId,
    required String targetId,
    required String displayName,
    String? connectionId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'accounting-connect',
        body: {
          'action': 'authorize',
          'workspace_id': workspaceId,
          'issuer_site_id': issuerSiteId,
          'target_id': targetId,
          'display_name': displayName,
          'connection_id': ?connectionId,
        },
      );
      final data = response.data;
      final url = data is Map ? Uri.tryParse('${data['authorize_url']}') : null;
      if (url == null || !url.hasScheme) {
        throw const FormatException('accounting-connect: no sign-in page');
      }
      return SignInPage(url);
    } on FunctionException catch (e, st) {
      if (e.status == _notConfigured) return const SignInNotConfigured();
      Error.throwWithStackTrace(e, st);
    }
  }

  @override
  Future<void> refresh(String connectionId) async {
    await _client.functions.invoke(
      'accounting-connect',
      body: {'action': 'refresh', 'connection_id': connectionId},
    );
  }

  @override
  Future<AccountingConnection> revoke(String connectionId) => _connection(
    'revoke_accounting_connection_v1',
    {'p_connection_id': connectionId},
  );

  @override
  Future<AccountingConnection> saveMap(
    String connectionId,
    AccountingMapDraft draft,
  ) => _connection('save_accounting_map_v1', {
    'p_connection_id': connectionId,
    'p_kind': draft.kind.wire,
    'p_key': draft.key,
    'p_remote_id': draft.remoteId,
    'p_remote_code': draft.remoteCode,
    'p_remote_name': draft.remoteName,
  });

  @override
  Future<AccountingConnection> deleteMap(String mapId) =>
      _connection('delete_accounting_map_v1', {'p_map_id': mapId});

  @override
  Future<AccountingTransfers> fetchTransfers(
    String workspaceId,
    DateTime from,
    DateTime to,
  ) async => AccountingTransfers.fromJson(
    await _client.rpc<Object?>(
      'accounting_transfers_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_from': isoDay(from),
        'p_to': isoDay(to),
      },
    ),
  );

  @override
  Future<FileDeliveryOutcome> recordFileDeliveries(
    String workspaceId, {
    required String targetId,
    required String issuerSiteId,
    required String bookExportId,
    required List<FileDocument> documents,
  }) async => FileDeliveryOutcome.fromJson(
    await _client.rpc<Object?>(
      'record_file_deliveries_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_target_id': targetId,
        'p_issuer_site_id': issuerSiteId,
        'p_book_export_id': bookExportId,
        'p_documents': [
          for (final d in documents)
            {
              'kind': d.kind,
              'id': d.id,
              'number': d.number,
              'date': isoDay(d.date),
              'sha256': d.sha256,
            },
        ],
      },
    ),
  );
}
