// SPDX-License-Identifier: 0BSD
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend/backend_config.dart';
import '../core/backend/backend_settings.dart';

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
  await Supabase.initialize(
    url: stored?.url ?? BackendConfig.supabaseUrl,
    publishableKey: stored?.key ?? BackendConfig.supabaseKey,
  );
}
