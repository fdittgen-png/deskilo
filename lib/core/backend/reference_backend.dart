// SPDX-License-Identifier: AGPL-3.0-or-later
import 'backend_config.dart';
import 'backend_settings.dart';

/// #2343 — the hosted reference deployment, offered by name in every
/// build, the default in none that was built without one.
const referenceEndpoint = BackendEndpoint(
  BackendConfig.referenceUrl,
  BackendConfig.referenceKey,
);

// #2561 L3 — the directory no longer lives on a constant: the installation
// declares its personal home (`directoryHomeOf`, personal_home.dart) and
// the reference deployment is what an installation that declared nothing
// keeps.

/// #2343 — whether [url] is the reference deployment's.
bool isReferenceBackend(String url) =>
    canonicalBackendUrl(url) == BackendConfig.referenceUrl;

/// #2343 — the server this build falls back to when nothing is stored:
/// the compiled default, or null in a build that ships none.
BackendEndpoint? get compiledDefaultEndpoint => BackendConfig.hasDefault
    ? const BackendEndpoint(
        BackendConfig.supabaseUrl,
        BackendConfig.supabaseKey,
      )
    : null;
