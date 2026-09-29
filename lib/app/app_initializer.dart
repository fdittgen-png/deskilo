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
Future<void> initializeApp() async {
  final stored = await const PrefsBackendSettingsStore().read();
  // #1124 — the cache is named after the server the rows came from, and
  // that is this one for the rest of the process, whatever Settings is
  // holding by the time somebody reads a row.
  bootBackendUrl = stored?.url ?? BackendConfig.supabaseUrl;
  final origin = Uri.parse(bootBackendUrl);
  const secrets = PlatformAuthSecretStore();
  final callback = Uri.parse(kIsWeb
      ? '${Uri.base.origin}${Uri.base.path}' : 'deskilo://auth-callback');
  final guard = AuthCallbackGuard(secrets, origin, callback);
  await guard.restore();
  bootAuthCallbackGuard = guard;
  final dispatch = AuthCallbackDispatcher(guard,
      currentUser: () => Supabase.instance.client.auth.currentUser?.id);
  await Supabase.initialize(
    url: stored?.url ?? BackendConfig.supabaseUrl,
    publishableKey: stored?.key ?? BackendConfig.supabaseKey,
    authOptions: FlutterAuthClientOptions(
      detectSessionInUriPredicate: dispatch.call,
      pkceAsyncStorage: InstallationPkceStorage(secrets, origin),
      localStorage: InstallationSessionStorage(secrets, origin,
        legacy: SharedPreferencesLocalStorage(
          persistSessionKey: 'sb-${origin.host.split('.').first}-auth-token',
        )),
    ),
  );
  await dispatch.attach((uri) async {
    try {
      await NativeFederationFlow(Supabase.instance.client, guard, secrets).complete(uri);
    } finally {
      clearCallbackHistory();
    }
  });
}
