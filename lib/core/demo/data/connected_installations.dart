// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../backend/auth_secret_store.dart';
import '../../backend/backend_settings.dart';
import '../../backend/connected_installations.dart';

class FakeConnectedInstallations extends ConnectedInstallations {
  FakeConnectedInstallations()
    : super(
        SupabaseClient(
          'https://demo.invalid',
          'sb_publishable_demo',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        _MemorySecrets(),
      );
  final sources = <ConnectedInstallation>[];
  @override
  Future<List<ConnectedInstallation>> list() async => sources;
  @override
  Future<void> requestCode(BackendEndpoint endpoint, String email) async {}
  @override
  Future<void> connect(
    BackendEndpoint endpoint,
    String email,
    String credential, {
    bool code = false,
  }) async {
    sources.add(
      ConnectedInstallation(
        endpoint: endpoint,
        account: 'demo',
        installationId: 'demo',
      ),
    );
  }

  @override
  Future<void> disconnect(String source) async {
    sources.removeWhere((s) => s.endpoint.url == source);
  }

  @override
  Future<T> use<T>(String source, Future<T> Function(SupabaseClient) action) =>
      Future.error(StateError('Demo has no external server'));

  /// #1832 — a test scripts each target's health; Demo's are usable.
  final health = <String, ConnectionFailure?>{};

  @override
  Future<ConnectionFailure?> check(String source) async => health[source];
}

class _MemorySecrets implements AuthSecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
