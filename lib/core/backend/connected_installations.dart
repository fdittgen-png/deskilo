// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_secret_store.dart';
import 'backend_settings.dart';

class ConnectedInstallation {
  const ConnectedInstallation({
    required this.endpoint,
    required this.account,
    required this.installationId,
  });
  final BackendEndpoint endpoint;
  final String account, installationId;
}

/// Each connection was separately authorized on its own server. The encrypted
/// collection belongs to one account AND its home origin, never to the device
/// globally. Neither email matching nor a canonical bearer joins accounts.
class ConnectedInstallations {
  ConnectedInstallations(
    this.active,
    this.secrets, {
    http.Client Function()? transport,
  }) : owner = active.auth.currentUser?.id,
       origin = Uri.parse(active.rest.url).origin,
       transport = transport ?? http.Client.new;
  final SupabaseClient active;
  final AuthSecretStore secrets;
  final http.Client Function() transport;
  final String? owner;
  final String origin;
  bool _closed = false;
  Future<void> _writes = Future.value();
  final _epochs = <String, int>{};
  final _reads = <String, Future<void>>{};
  String get _key =>
      'deskilo.connections.${sha256.convert(utf8.encode('$origin\n$owner'))}';
  void _check() {
    if (_closed || owner == null || active.auth.currentUser?.id != owner) {
      throw StateError('account changed');
    }
  }

  void close() {
    _closed = true;
  }

  Future<Map<String, dynamic>> _records() async {
    _check();
    final raw = await secrets.read(_key);
    _check();
    return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _write(
    String source,
    Map<String, dynamic>? record, {
    int? epoch,
  }) {
    final next = _writes.then((_) async {
      if (epoch != null && epoch != (_epochs[source] ?? 0)) {
        throw StateError('connection changed');
      }
      final records = await _records();
      if (epoch != null && epoch != (_epochs[source] ?? 0)) {
        throw StateError('connection changed');
      }
      if (record == null) {
        records.remove(source);
      } else {
        records[source] = record;
      }
      _check();
      await secrets.write(_key, jsonEncode(records));
    });
    // trace-exempt: callers receive the exception; this tail only serializes writes.
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<List<ConnectedInstallation>> list() async {
    final records = await _records();
    return [
      for (final entry in records.entries)
        ConnectedInstallation(
          endpoint: BackendEndpoint(
            entry.key,
            (entry.value as Map)['key'] as String,
          ),
          account: (entry.value as Map)['account'] as String,
          installationId: (entry.value as Map)['installation_id'] as String,
        ),
    ];
  }

  SupabaseClient _client(BackendEndpoint endpoint) {
    if (validateBackendEndpoint(endpoint.url, endpoint.key) != null) {
      throw StateError('invalid endpoint');
    }
    return SupabaseClient(
      endpoint.url,
      endpoint.key,
      httpClient: OriginOnlyClient(Uri.parse(endpoint.url).origin, transport()),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }

  Future<void> requestCode(BackendEndpoint endpoint, String email) async {
    _check();
    final client = _client(endpoint);
    try {
      await client.auth
          .signInWithOtp(email: email.trim(), shouldCreateUser: false)
          .timeout(const Duration(seconds: 20));
    } finally {
      await client.dispose();
    }
    _check();
  }

  Future<void> connect(
    BackendEndpoint endpoint,
    String email,
    String credential, {
    bool code = false,
  }) async {
    _check();
    final source = canonicalBackendUrl(endpoint.url)!;
    if (source == origin) throw StateError('already the current server');
    final epoch = (_epochs[source] ?? 0) + 1;
    _epochs[source] = epoch;
    final client = _client(BackendEndpoint(source, endpoint.key.trim()));
    try {
      if (code) {
        await client.auth.verifyOTP(
          email: email.trim(),
          token: credential.trim(),
          type: OtpType.email,
        );
      } else {
        await client.auth.signInWithPassword(
          email: email.trim(),
          password: credential,
        );
      }
      final user = (await client.auth.getUser()).user;
      final session = client.auth.currentSession;
      if (user == null || session == null || user.id != session.user.id) {
        throw StateError('target authentication failed');
      }
      final identity = await client
          .from('installation_identity')
          .select('installation_id')
          .single();
      await client.rpc<Object?>(
        'my_financial_activity',
        params: {'p_kind': 'invoices'},
      );
      _check();
      await _write(source, {
        'key': endpoint.key.trim(),
        'account': user.id,
        'installation_id': identity['installation_id'],
        'session': session.toJson(),
      }, epoch: epoch);
    } finally {
      await client.dispose();
    }
  }

  Future<T> use<T>(String source, Future<T> Function(SupabaseClient) action) {
    final next = (_reads[source] ?? Future<void>.value()).then(
      (_) => _use(source, action),
    );
    // trace-exempt: returned future reports the failure; serialize refreshes per origin.
    _reads[source] = next.then<void>((_) {}).catchError((Object _) {});
    return next;
  }

  Future<T> _use<T>(
    String source,
    Future<T> Function(SupabaseClient) action,
  ) async {
    _check();
    if (source.isEmpty || source == origin) {
      final result = await action(active);
      _check();
      return result;
    }
    final epoch = _epochs[source] ?? 0;
    final record = (await _records())[source] as Map<String, dynamic>?;
    if (record == null) throw StateError('server is not connected');
    final client = _client(BackendEndpoint(source, record['key'] as String));
    try {
      await client.auth.setInitialSession(jsonEncode(record['session']));
      final session = client.auth.currentSession;
      if (session == null) throw StateError('sign in again');
      if (session.isExpired) await client.auth.refreshSession();
      final user = (await client.auth.getUser()).user;
      if (user?.id != record['account']) {
        throw StateError('target account changed');
      }
      final identity = await client
          .from('installation_identity')
          .select('installation_id')
          .single();
      if (identity['installation_id'] != record['installation_id']) {
        throw StateError('installation changed');
      }
      _check();
      final result = await action(client).timeout(const Duration(seconds: 20));
      _check();
      await _write(source, {
        ...record,
        'session': client.auth.currentSession!.toJson(),
      }, epoch: epoch);
      return result;
    } finally {
      await client.dispose();
    }
  }

  Future<void> disconnect(String source) async {
    // Delete locally even when the remote server is unavailable. No unrelated
    // installation or main app session is signed out.
    _epochs[source] = (_epochs[source] ?? 0) + 1;
    await _write(source, null);
  }
}

/// Never follow a redirect carrying any installation's key or bearer elsewhere.
class OriginOnlyClient extends http.BaseClient {
  OriginOnlyClient(this.origin, this.inner);
  final String origin;
  final http.Client inner;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.origin != origin) {
      throw StateError('cross-origin request refused');
    }
    request.followRedirects = false;
    return inner.send(request).timeout(const Duration(seconds: 20));
  }

  @override
  void close() => inner.close();
}
