// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/workbook_origin.dart';

/// Uses this client's native session and own-identity RPC, including when no
/// federation authority is configured. No URL, token or account is exported.
class SupabaseWorkbookOriginRepository implements WorkbookOriginRepository {
  const SupabaseWorkbookOriginRepository(this._client);
  final SupabaseClient _client;

  // The Auth-issued session id survives refresh but changes on a fresh login.
  // This is only a stale-response guard; it grants no authority from claims.
  String _sessionId() {
    final parts = _client.auth.currentSession?.accessToken.split('.');
    if (parts == null || parts.length != 3) throw StateError('workbook_session_unavailable');
    try {
      final value = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final id = value is Map ? value['session_id'] : null;
      if (id is! String || id.isEmpty) throw StateError('workbook_session_unavailable');
      return id;
    } on FormatException {
      // trace-exempt: parser errors can quote bearer contents; replace them.
      throw StateError('workbook_session_unavailable');
    }
  }

  @override
  Future<WorkbookOrigin> read() async {
    final account = _client.auth.currentUser?.id;
    if (account == null) throw StateError('workbook_source_unavailable');
    final session = _sessionId();
    final value = await _client.rpc<Object?>('my_identity_status');
    final id = value is Map ? value['installation_id'] : null;
    if (_client.auth.currentUser?.id != account || _sessionId() != session || id is! String ||
        !RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$').hasMatch(id)) {
      throw StateError('workbook_source_unavailable');
    }
    return WorkbookOrigin(
      sourceId: sha256.convert(utf8.encode(_client.rest.url)).toString(),
      installationId: id.toLowerCase(), accountId: account, sessionId: session,
    );
  }
}
