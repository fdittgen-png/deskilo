// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/backend/context_client_providers.dart';
import '../../../core/cache/cache_store.dart';
import '../../../core/instance/settings_bundle_asset.dart';
import '../../../core/settings/active_settings.dart';
import '../../../core/settings/platform_settings.dart';
import '../../../core/settings/settings.dart';
import '../../../core/settings/settings_capture.dart';
import '../../auth/providers/auth_providers.dart';
import '../application/settings_commands.dart';
import '../data/host_bound_settings_store.dart';
import 'workspace_providers.dart';

part 'settings_providers.g.dart';

/// #2484 -- the settings registry: read and written.
///
/// #2564 -- on the host the workspace lives on, when it lives on a connected
/// installation. That host is found by the resolver, which depends on the
/// selection only, at each call and with the pin given back afterwards
/// (`ref.read` inside the scope, not a watch): this provider and the context
/// that captures the settings stay two nodes with no edge between them, so
/// the cycle that once rebuilt without end (selectedWorkspaceClient ->
/// workspaceContext -> currentSettingsCapture -> settingsSource ->
/// settingsRepository) cannot form. A workspace other than the selected
/// connected one and the combined deployment stay on the installation the
/// app is signed in to; the platform's own view (no workspace) is the
/// personal home's (#2561 L3).
@Riverpod(keepAlive: true)
SettingsStore settingsRepository(Ref ref) {
  final clients = ref.watch(contextClientsProvider);
  return HostBoundSettingsStore(<T>(workspaceId, use) async {
    final selected = ref.read(selectedWorkspaceHostProvider);
    // #2561 L3 -- the platform's own view is the personal home's.
    if (workspaceId == null) return use(clients.personal);
    if (selected == null || selected.workspaceId != workspaceId) {
      return use(clients.legacyActive);
    }
    final host = await ref
        .read(workspaceHostResolverProvider)
        .resolve(workspaceId);
    try {
      return await use(host.client);
    } finally {
      host.lease?.release();
    }
  }, ref.watch(cacheStoreProvider));
}

/// The registry, falling back to the definitions bundled with the app
/// (defaults only) when the installation cannot answer.
@Riverpod(keepAlive: true)
SettingsSource settingsSource(Ref ref) => BundledFallbackSettingsSource(
      ref.watch(settingsRepositoryProvider),
      ref.watch(settingsBundleLoaderProvider),
    );

/// Changing a setting (the editor's decision).
@riverpod
SettingsCommands settingsCommands(Ref ref) =>
    SettingsCommands(ref.watch(settingsRepositoryProvider));

/// The registry and every effective value for [workspaceId] (null: the
/// platform's own view). A different person re-reads it (the provider
/// watches the session); a write invalidates it.
@Riverpod(keepAlive: true)
Future<SettingsSet> settingsSet(Ref ref, String? workspaceId) async {
  final source = ref.watch(settingsSourceProvider);
  final signedIn = ref.watch(authStateProvider).value != null;
  if (!signedIn) return SettingsSet.defaults(const []);
  return source.load(workspaceId);
}

/// The ACTIVE workspace's settings snapshot, for the code that works in it
/// (dunning, booking...). Re-read for a different person or workspace;
/// invalidate it after a write.
@Riverpod(keepAlive: true)
Future<SettingsSet> currentSettings(Ref ref) async {
  final capture = await ref.watch(currentSettingsCaptureProvider.future);
  return capture?.settings ?? SettingsSet.defaults(const []);
}

/// #2589 C1 -- the active workspace's settings as an operation takes them:
/// the identity (installation, workspace, signed-in user) is fixed BEFORE the
/// read awaits, and the result is an immutable [SettingsCapture]. Signed out
/// there is nothing to capture, so the answer is null -- never another
/// person's or workspace's values.
@Riverpod(keepAlive: true)
Future<SettingsCapture?> currentSettingsCapture(Ref ref) async {
  final source = ref.watch(settingsSourceProvider);
  final installation = ref.watch(bootedBackendUrlProvider);
  final platform = ref.watch(platformSettingsReaderProvider);
  final principalAnswer = ref.watch(authStateProvider.future);
  final workspaceAnswer = ref.watch(currentWorkspaceProvider.future);
  final principal = await principalAnswer;
  final workspace = (await workspaceAnswer)?.id;
  if (principal == null) return null;
  // #2561 L3 -- no workspace (a personal home hosts none): the personal
  // home's own platform scope, never a dummy workspace or another host.
  if (workspace == null) return platform.read(principal);
  return captureSettings(
    source,
    SettingsIdentity(
      installation: installation,
      workspaceId: workspace,
      principal: principal,
    ),
  );
}

/// #2486 -- the active workspace's settings for core/settings readers (the
/// booking and directory windows); the composition root puts it in its
/// scope's overrides.
final activeSettingsFromWorkspace = activeSettingsProvider.overrideWith(
  (ref) => ref.watch(currentSettingsProvider).asData?.value,
);

/// #2553 C2 -- hands the personal home's platform settings to core
/// (`platformSettingsProvider`) for the signed-in person; the composition
/// root puts it in its scope's overrides.
final platformSettingsFromWorkspace = platformSettingsProvider.overrideWith(
  (ref) {
    final reader = ref.watch(platformSettingsReaderProvider);
    final principal = ref.watch(authStateProvider.future);
    return principal.then((who) async => (await reader.read(who))?.settings);
  },
);

/// #2561 L3 -- the personal home's platform settings: the registry's
/// platform scope read with a null workspace, which [settingsRepository]
/// serves on the PERSONAL client, so a personal home that hosts no workspace
/// has them and no selected workspace (or its host) decides them.
@Riverpod(keepAlive: true)
PlatformSettingsReader platformSettingsReader(Ref ref) =>
    PlatformSettingsReader(
      source: ref.watch(settingsSourceProvider),
      installation: ref.watch(bootedBackendUrlProvider),
    );
