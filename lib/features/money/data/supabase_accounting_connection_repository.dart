// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/accounting_connection.dart';
import '../domain/accounting_delivery_run.dart';
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

  /// The HTTP status of a delivery the server refused as a whole (the
  /// books blocked, the target refusing the company, a signed-out
  /// connection); its body says which.
  static const _runRefused = 409;

  /// The HTTP status of a connection the server does not check by its
  /// token (an OAuth connection, or a target without that check).
  static const _notChecked = 400;

  /// The HTTP status of a caller the server refused: they may not deliver
  /// for this connection or read these books.
  static const _notAllowed = 403;

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
  Future<CapabilityState> fetchCapabilityState(String workspaceId) async {
    final result = await _client.rpc<Object?>(
      'capability_states_v1',
      params: {'p_workspace_id': workspaceId},
    );
    final list = result is List ? result : const <Object?>[];
    final first = list.isEmpty ? null : list.first;
    return CapabilityState.fromJson(
      first is Map
          ? Map<String, Object?>.from(first)
          : const <String, Object?>{},
    );
  }

  @override
  Future<CapabilityState> setCapabilityState(
    String workspaceId,
    CapabilityStateKind to,
    String reason,
  ) async {
    await _client.rpc<Object?>(
      'set_capability_state_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_key': 'accountingConnectors',
        'p_to': to.wire,
        'p_reason': reason,
      },
    );
    // the server recorded who and when: read it back rather than guess
    return fetchCapabilityState(workspaceId);
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
  }) async {
    final stored = await _connection('set_accounting_token_v1', {
      'p_connection_id': connectionId,
      'p_token': token,
      'p_remote_tenant_id': remoteTenantId,
    });
    await _verifyCompany(connectionId);
    return stored;
  }

  /// Asks the target which company the stored token reaches. A company
  /// other than the one named, or one the target will not name, is
  /// recorded on the connection by the server (state `error`, with the
  /// target's words) and read with the connections; nothing is delivered to
  /// it. A target the server does not check by its token answers 400.
  Future<void> _verifyCompany(String connectionId) async {
    try {
      await _client.functions.invoke(
        'accounting-connect',
        body: {'action': 'verify', 'connection_id': connectionId},
      );
    } on FunctionException catch (e, st) {
      if (e.status != _runRefused && e.status != _notChecked) {
        Error.throwWithStackTrace(e, st);
      }
    }
  }

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

  /// #3906 — the code and the state go to the function only; a refusal is
  /// read from its status and error key, never from the request.
  @override
  Future<SignInCompletion> completeSignIn(SignInReturn back) async {
    try {
      await _client.functions.invoke(
        'accounting-connect',
        body: {
          'action': 'complete',
          'state': back.state,
          'code': back.code,
          if (back.error.isNotEmpty) 'error': back.error,
          if (back.tenant.isNotEmpty) 'tenant': back.tenant,
        },
      );
      return SignInCompletion.connected;
    } on FunctionException catch (e, st) {
      final key = e.details is Map ? '${(e.details as Map)['error']}' : '';
      // The status and the function's error key only: the request carried
      // a one-time credential.
      TraceLogger.instance.warn(
        'money',
        'accounting sign-in not completed: ${e.status} $key\n$st',
      );
      return switch (e.status) {
        403 when key == 'started_by_someone_else' =>
          SignInCompletion.startedBySomeoneElse,
        403 => SignInCompletion.refused,
        400 when key == 'state_invalid' || key == 'state_expired' =>
          SignInCompletion.expired,
        _ => SignInCompletion.failed,
      };
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
  Future<AccountingConnection> revoke(String connectionId) async {
    // The server revokes the connection here first and then, where the
    // target documents it (RFC 7009), at the target: a target that does not
    // confirm leaves the connection revoked all the same.
    final response = await _client.functions.invoke(
      'accounting-connect',
      body: {'action': 'revoke', 'connection_id': connectionId},
    );
    final data = response.data;
    return AccountingConnection.fromJson(data is Map ? data['connection'] : null);
  }

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

  @override
  Future<DeliveryRun> deliver(
    String connectionId, {
    required DateTime from,
    required DateTime to,
    ({String kind, String id})? document,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'accounting-connect',
        body: {
          'action': 'deliver',
          'connection_id': connectionId,
          'from': isoDay(from),
          'to': isoDay(to),
          if (document != null) 'document': {'kind': document.kind, 'id': document.id},
        },
      );
      return DeliveryRunDone.fromJson(response.data);
    } on FunctionException catch (e, st) {
      if (e.status == _notAllowed) return const DeliveryRunNotAllowed();
      final refusal = e.status == _runRefused ? deliveryRunRefusal(e.details) : null;
      if (refusal != null) return refusal;
      Error.throwWithStackTrace(e, st);
    }
  }
}
