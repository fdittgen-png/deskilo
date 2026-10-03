// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../trace/trace_logger.dart';
import 'auth_secret_store.dart';
import 'backend_settings.dart';
import 'connection_outcome.dart';

export 'connection_outcome.dart';

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
///
/// #1832 A — every failure is a typed [ConnectionFailure]; a committed
/// action is never reported as failed because saving the refreshed session
/// failed afterwards; a target whose installation (or account) changed is
/// quarantined until it is connected again.
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

  /// Targets whose last committed action could not save its refreshed
  /// session: the result stood, the next use may need a sign-in again.
  final _unsaved = <String>{};
  String get _key =>
      'deskilo.connections.${sha256.convert(utf8.encode('$origin\n$owner'))}';
  void _check([String source = '']) {
    if (_closed || owner == null || active.auth.currentUser?.id != owner) {
      throw ConnectionFailure(source, ConnectionFailureReason.cancelled);
    }
  }

  /// Whether [source]'s last committed action left its refreshed session
  /// unsaved on this device.
  bool sessionNotSaved(String source) => _unsaved.contains(source);

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
        throw ConnectionFailure(source, ConnectionFailureReason.cancelled);
      }
      final records = await _records();
      if (epoch != null && epoch != (_epochs[source] ?? 0)) {
        throw ConnectionFailure(source, ConnectionFailureReason.cancelled);
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
      throw ConnectionFailure(
        endpoint.url,
        ConnectionFailureReason.invalidEndpoint,
      );
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
    } catch (e, st) {
      // trace-exempt: rethrown as the typed outcome, stack kept; the caller traces.
      Error.throwWithStackTrace(
        classifyConnectionError(e, source: endpoint.url),
        st,
      );
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
    final source = canonicalBackendUrl(endpoint.url);
    if (source == null) {
      throw ConnectionFailure(
        endpoint.url,
        ConnectionFailureReason.invalidEndpoint,
      );
    }
    if (source == origin) {
      throw ConnectionFailure(source, ConnectionFailureReason.currentServer);
    }
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
      await _register(source, endpoint.key.trim(), client, epoch);
    } catch (e, st) {
      // trace-exempt: rethrown as the typed outcome, stack kept; the caller traces.
      Error.throwWithStackTrace(classifyConnectionError(e, source: source), st);
    } finally {
      await client.dispose();
    }
  }

  /// #1834 — keeps a session that the identity flow obtained on
  /// [endpoint]'s OWN server (a target-native session whose binding that
  /// server verified). The same checks and the same record as [connect]:
  /// no password, no second registration, and nothing granted. The target
  /// must still be [installationId], the installation the flow was for.
  Future<void> adopt(
    BackendEndpoint endpoint,
    Session session, {
    required String installationId,
  }) async {
    _check();
    final source = canonicalBackendUrl(endpoint.url);
    if (source == null) {
      throw ConnectionFailure(
        endpoint.url,
        ConnectionFailureReason.invalidEndpoint,
      );
    }
    if (source == origin) {
      throw ConnectionFailure(source, ConnectionFailureReason.currentServer);
    }
    final epoch = (_epochs[source] ?? 0) + 1;
    _epochs[source] = epoch;
    final client = _client(BackendEndpoint(source, endpoint.key.trim()));
    try {
      // The canonical provider's tokens never reach a target data API.
      final native = session.toJson()
        ..remove('provider_token')
        ..remove('provider_refresh_token');
      await client.auth.setInitialSession(jsonEncode(native));
      await _register(
        source,
        endpoint.key.trim(),
        client,
        epoch,
        installationId: installationId,
      );
    } catch (e, st) {
      // trace-exempt: rethrown as the typed outcome, stack kept; the caller traces.
      Error.throwWithStackTrace(classifyConnectionError(e, source: source), st);
    } finally {
      await client.dispose();
    }
  }

  /// Verifies [client]'s signed-in session against its own server and
  /// saves the connection. [installationId], when given, is the
  /// installation the caller expects; another one is refused.
  Future<void> _register(
    String source,
    String key,
    SupabaseClient client,
    int epoch, {
    String? installationId,
  }) async {
    final user = (await client.auth.getUser()).user;
    final session = client.auth.currentSession;
    if (user == null || session == null || user.id != session.user.id) {
      throw ConnectionFailure(source, ConnectionFailureReason.denied);
    }
    final identity = await client
        .from('installation_identity')
        .select('installation_id')
        .single();
    final installation = identity['installation_id'];
    if (installation is! String || installation.isEmpty) {
      throw ConnectionFailure(source, ConnectionFailureReason.malformed);
    }
    if (installationId != null && installation != installationId) {
      throw ConnectionFailure(source, ConnectionFailureReason.changedIdentity);
    }
    // #1832 — compatibility comes from the target's public descriptor
    // (#1847), not from reading the account's invoices: connecting reads
    // no private payload and runs no financial operation.
    if (!connectableProfile(await describeTarget(client))) {
      throw ConnectionFailure(source, ConnectionFailureReason.unsupported);
    }
    _check(source);
    await _write(source, {
      'key': key,
      'account': user.id,
      'installation_id': installation,
      'session': session.toJson(),
    }, epoch: epoch);
    _unsaved.remove(source);
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
    _check(source);
    if (source.isEmpty || source == origin) {
      final result = await action(active);
      _check(source);
      return result;
    }
    final epoch = _epochs[source] ?? 0;
    final record = (await _records())[source] as Map<String, dynamic>?;
    if (record == null) {
      throw ConnectionFailure(source, ConnectionFailureReason.notConnected);
    }
    // A quarantined target is not called at all until it is connected
    // again: a retry must not silently trust a replacement backend.
    if (record['quarantined'] == true) {
      throw ConnectionFailure(source, ConnectionFailureReason.changedIdentity);
    }
    final client = _client(BackendEndpoint(source, record['key'] as String));
    try {
      await _verify(source, record, epoch, client);
      _check(source);
      final T result;
      try {
        result = await action(client).timeout(const Duration(seconds: 20));
      } on TimeoutException catch (_, st) {
        // trace-exempt: rethrown as the typed outcome, stack kept; the caller traces.
        Error.throwWithStackTrace(
          ConnectionFailure(
            source,
            ConnectionFailureReason.unavailable,
            afterSend: true,
          ),
          st,
        );
      } catch (e, st) {
        // The action's own refusals are the business answer and pass
        // through; only a lost transport becomes "outcome unknown".
        if (!isTransientNetworkFailure(e)) rethrow;
        TraceLogger.instance.warn('connections', 'transport lost after send',
            error: e.runtimeType, stackTrace: st);
        throw ConnectionFailure(
          source,
          ConnectionFailureReason.unavailable,
          afterSend: true,
        );
      }
      _check(source);
      await _saveSession(source, record, epoch, client);
      return result;
    } finally {
      await client.dispose();
    }
  }

  /// The target is still the account and the installation that were
  /// connected; a change quarantines it.
  Future<void> _verify(
    String source,
    Map<String, dynamic> record,
    int epoch,
    SupabaseClient client,
  ) async {
    try {
      await client.auth.setInitialSession(jsonEncode(record['session']));
      final session = client.auth.currentSession;
      if (session == null) {
        throw ConnectionFailure(source, ConnectionFailureReason.expired);
      }
      if (session.isExpired) await client.auth.refreshSession();
      final user = (await client.auth.getUser()).user;
      final identity = await client
          .from('installation_identity')
          .select('installation_id')
          .single();
      if (user?.id != record['account'] ||
          identity['installation_id'] != record['installation_id']) {
        await _quarantine(source, record, epoch);
        throw ConnectionFailure(source, ConnectionFailureReason.changedIdentity);
      }
    } catch (e, st) {
      // trace-exempt: rethrown as the typed outcome, stack kept; the caller traces.
      Error.throwWithStackTrace(classifyConnectionError(e, source: source), st);
    }
  }

  Future<void> _quarantine(
    String source,
    Map<String, dynamic> record,
    int epoch,
  ) async {
    try {
      await _write(source, {...record, 'quarantined': true}, epoch: epoch);
    } catch (e, st) {
      // The refusal stands either way; a quarantine that could not be
      // saved is asked again (and refused again) on the next use.
      TraceLogger.instance.warn('connections', 'quarantine not saved',
          error: e.runtimeType, stackTrace: st);
    }
  }

  /// Saves the refreshed session after a COMMITTED action. A stale intent
  /// (account changed, connection removed) still fails; a storage failure
  /// does not turn the committed result into a failure — it is remembered,
  /// and the next use asks for a sign-in again if the session is gone.
  Future<void> _saveSession(
    String source,
    Map<String, dynamic> record,
    int epoch,
    SupabaseClient client,
  ) async {
    try {
      await _write(source, {
        ...record,
        'session': client.auth.currentSession!.toJson(),
      }, epoch: epoch);
      _unsaved.remove(source);
    } on ConnectionFailure {
      rethrow;
    } catch (e, st) {
      _unsaved.add(source);
      TraceLogger.instance.warn(
        'connections',
        'session not saved after a committed action',
        error: e.runtimeType,
        stackTrace: st,
      );
    }
  }

  /// Whether [source] can be used now, and if not, why. Asks the target
  /// the same questions an action would (session, account, installation)
  /// plus whether this build can speak to it; runs no business operation.
  /// Null means usable.
  Future<ConnectionFailure?> check(String source) async {
    try {
      await use(source, (client) async {
        if (!connectableProfile(await describeTarget(client))) {
          throw ConnectionFailure(source, ConnectionFailureReason.unsupported);
        }
      });
      return null;
    } catch (e, st) {
      final failure = classifyConnectionError(e, source: source);
      TraceLogger.instance.log(
        TraceLevel.info,
        'connections',
        'check: ${failure.reason.name}',
        stackTrace: st,
      );
      return failure;
    }
  }

  Future<void> disconnect(String source) async {
    // Delete locally even when the remote server is unavailable. No unrelated
    // installation or main app session is signed out.
    _epochs[source] = (_epochs[source] ?? 0) + 1;
    _unsaved.remove(source);
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
