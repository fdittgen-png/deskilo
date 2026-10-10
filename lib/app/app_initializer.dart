// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../core/backend/backend_config.dart';
import '../core/backend/backend_settings.dart';
import '../core/backend/auth_secret_store.dart';
import '../core/backend/installation_auth_storage.dart';
import '../core/backend/auth_callback_dispatch.dart';
import '../core/backend/auth_callback_guard.dart';
import '../core/backend/native_federation_flow.dart';
import '../core/backend/callback_history.dart';
import '../core/cache/cache_scope.dart';

/// One-time async bootstrap before runApp (Sparkilo pattern).
///
/// Widget tests never call this — they override the repository providers
/// with fakes instead (test/helpers/mock_providers.dart).
///
/// #780 — the endpoint is read from the device store FIRST: a community
/// pointing the app at its own Supabase project set it in Settings, and
/// that choice has to be in force before the first request. No stored
/// endpoint (the normal case, and every store build) = the compiled
/// defaults.
Future<void> initializeApp({
  StartupStages stages = const StartupStages(),
}) async {
  // #2343 — a build without a default server reaches this only after
  // the first-start choice stored one ([needsServerChoice]).
  final endpoint = await stages.readStored() ?? compiledDefaultEndpoint;
  if (endpoint == null) throw StateError('no server chosen');
  // #1124 — the cache is named after the server the rows came from, and
  // that is this one for the rest of the process, whatever Settings is
  // holding by the time somebody reads a row.
  bootBackendUrl = endpoint.url;
  final origin = Uri.parse(bootBackendUrl);
  const secrets = PlatformAuthSecretStore();
  final callback = Uri.parse(kIsWeb
      ? '${Uri.base.origin}${Uri.base.path}' : 'deskilo://auth-callback');
  final guard = AuthCallbackGuard(secrets, origin, callback);
  await stages.restoreGuard(guard);
  bootAuthCallbackGuard = guard;
  final dispatch = AuthCallbackDispatcher(guard,
      currentUser: () => Supabase.instance.client.auth.currentUser?.id);
  bootAuthCallbackDispatcher = dispatch;
  await stages.initializeSupabase(
    url: endpoint.url,
    key: endpoint.key,
    dispatch: dispatch,
    secrets: secrets,
    origin: origin,
  );
  await stages.attachCallback(dispatch, guard, secrets);
}

/// #2343 — true when this build ships no default server and the device
/// has not chosen one yet: the first start must ask before anything is
/// contacted.
Future<bool> needsServerChoice({
  bool hasDefault = BackendConfig.hasDefault,
  Future<BackendEndpoint?> Function() readStored = _readStored,
}) async =>
    !hasDefault && await readStored() == null;

/// #2015 — the four asynchronous stages of the essential start-up, as seams.
///
/// The defaults are the real ones; a test hands in a stage that hangs or
/// throws and drives the REAL [initializeApp] around it, so the recovery
/// proof covers the code that runs in production, not a copy of it.
class StartupStages {
  const StartupStages({
    this.readStored = _readStored,
    this.restoreGuard = _restoreGuard,
    this.initializeSupabase = _initializeSupabase,
    this.attachCallback = _attachCallback,
  });

  final Future<BackendEndpoint?> Function() readStored;
  final Future<void> Function(AuthCallbackGuard guard) restoreGuard;
  final Future<void> Function({
    required String url,
    required String key,
    required AuthCallbackDispatcher dispatch,
    required PlatformAuthSecretStore secrets,
    required Uri origin,
  }) initializeSupabase;
  final Future<void> Function(
    AuthCallbackDispatcher dispatch,
    AuthCallbackGuard guard,
    PlatformAuthSecretStore secrets,
  ) attachCallback;
}

Future<BackendEndpoint?> _readStored() =>
    const PrefsBackendSettingsStore().read();

Future<void> _restoreGuard(AuthCallbackGuard guard) => guard.restore();

Future<void> _initializeSupabase({
  required String url,
  required String key,
  required AuthCallbackDispatcher dispatch,
  required PlatformAuthSecretStore secrets,
  required Uri origin,
}) =>
    Supabase.initialize(
      url: url,
      publishableKey: key,
      authOptions: FlutterAuthClientOptions(
        detectSessionInUriPredicate: dispatch.call,
        pkceAsyncStorage: InstallationPkceStorage(secrets, origin),
        localStorage: InstallationSessionStorage(secrets, origin,
          legacy: SharedPreferencesLocalStorage(
            persistSessionKey: 'sb-${origin.host.split('.').first}-auth-token',
          )),
      ),
    );

Future<void> _attachCallback(
  AuthCallbackDispatcher dispatch,
  AuthCallbackGuard guard,
  PlatformAuthSecretStore secrets,
) =>
    dispatch.attach((uri) async {
      try {
        await NativeFederationFlow(Supabase.instance.client, guard, secrets)
            .complete(uri);
      } finally {
        clearCallbackHistory();
      }
    });
