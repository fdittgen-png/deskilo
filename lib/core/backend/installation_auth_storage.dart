// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_secret_store.dart';
import '../trace/trace_logger.dart';

/// Full origin, including port: two installations on one hostname must never
/// share a verifier or refresh token. The namespace carries no credential.
String installationAuthNamespace(Uri origin, String purpose) =>
    'deskilo.auth.${sha256.convert(utf8.encode('${origin.origin}\n$purpose'))}';

class InstallationPkceStorage extends GotrueAsyncStorage {
  InstallationPkceStorage(this.store, Uri origin, {String purpose = 'native'})
    : namespace = installationAuthNamespace(origin, '$purpose.pkce');
  final AuthSecretStore store;
  final String namespace;
  @override
  Future<String?> getItem({required String key}) =>
      store.read('$namespace.$key');
  @override
  Future<void> setItem({required String key, required String value}) =>
      store.write('$namespace.$key', value);
  @override
  Future<void> removeItem({required String key}) =>
      store.delete('$namespace.$key');
}

/// One selected native account per installation. Writes and logout are ordered
/// so a delayed refresh cannot race a queued logout and resurrect persistence.
/// Other installations have entirely separate account selectors and secrets.
class InstallationSessionStorage extends LocalStorage {
  InstallationSessionStorage(this.store, this.origin, {this.legacy})
    : namespace = installationAuthNamespace(origin, 'native.session');
  final AuthSecretStore store;
  final Uri origin;
  final LocalStorage? legacy;
  final String namespace;
  Future<void> _pending = Future.value();
  String get _selection => '$namespace.account';
  String _sessionKey(String account) => '$namespace.$account';

  Future<void> _ordered(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    // trace-exempt: the returned future reports storage failure to its caller;
    // only the internal sequencing tail recovers, without logging credentials.
    _pending = next.catchError((Object _) {});
    return next;
  }

  @override
  Future<void> initialize() async {
    final previous = legacy;
    if (previous == null) return;
    await previous.initialize();
    if (await store.read(_selection) != null) return;
    final value = await previous.accessToken();
    if (value == null || !_belongsHere(value)) return;
    await persistSession(value);
    // Remove the old copy only after the protected write has succeeded.
    await previous.removePersistedSession();
  }

  bool _belongsHere(String value) {
    try {
      final session = jsonDecode(value) as Map<String, dynamic>;
      final token = session['access_token'] as String;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      ) as Map<String, dynamic>;
      final issuer = claims['iss'];
      // Legacy hosted tokens used a common issuer but their SDK key includes
      // the unique Supabase project ref. Do not allow that exception on BYO.
      return issuer == '${origin.origin}/auth/v1' ||
          (issuer == 'supabase' &&
              origin.host.endsWith('.supabase.co') &&
              origin.scheme == 'https' &&
              origin.port == 443);
    } catch (error, stack) {
      // trace-exempt: malformed legacy secrets are never printed or migrated.
      TraceLogger.instance.warn(
        'auth',
        'invalid legacy session metadata',
        stackTrace: stack,
      );
      return false;
    }
  }

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;
  @override
  Future<String?> accessToken() async {
    await _pending;
    final account = await store.read(_selection);
    return account == null ? null : store.read(_sessionKey(account));
  }

  @override
  Future<void> persistSession(String persistSessionString) =>
      _ordered(() async {
        final json = jsonDecode(persistSessionString) as Map<String, dynamic>;
        final user = json['user'] as Map<String, dynamic>?;
        final account = user?['id'];
        if (account is! String || account.isEmpty) {
          throw StateError('session has no account');
        }
        final old = await store.read(_selection);
        await store.write(_sessionKey(account), persistSessionString);
        await store.write(_selection, account);
        if (old != null && old != account) await store.delete(_sessionKey(old));
      });

  @override
  Future<void> removePersistedSession() => _ordered(() async {
    final account = await store.read(_selection);
    await store.delete(_selection);
    if (account != null) await store.delete(_sessionKey(account));
    await legacy?.removePersistedSession();
  });
}
