// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/settings/active_settings.dart';

import '../data/prefs_discovery_view_store.dart';
import '../domain/discovery_view.dart';
import 'saved_places_providers.dart';

part 'discovery_view_providers.g.dart';

/// The device-local store of the discovery view preference.
@Riverpod(keepAlive: true)
DiscoveryViewStore discoveryViewStore(Ref ref) =>
    const PrefsDiscoveryViewStore();

/// The map services discovery's map is drawn from (#2488): the platform's
/// stored endpoints, else this build's, else the documented defaults. Until
/// the platform settings arrive (or signed out) the build's choice stands.
@Riverpod(keepAlive: true)
MapServices mapServices(Ref ref) =>
    MapServices.resolve(ref.watch(platformSettingsProvider).value);

/// List or map, and the map provider accepted, for the signed-in person
/// at their personal home on this device. Signed out, the choice is held
/// for this screen only and nothing is written.
@riverpod
class DiscoveryView extends _$DiscoveryView {
  @override
  Future<DiscoveryViewPreference> build() async {
    final namespace = await ref.watch(savedPlacesNamespaceProvider.future);
    if (namespace == null) return const DiscoveryViewPreference();
    return await ref.watch(discoveryViewStoreProvider).read(namespace) ??
        const DiscoveryViewPreference();
  }

  /// Shows the list, or the map when [map]; the map is only shown for a
  /// provider already accepted. Answers whether the asked view is shown
  /// (#3684): a refused map is said by the caller, never swallowed.
  Future<bool> show({required bool map}) async {
    final current = await future;
    if (map && !current.accepts(ref.read(mapServicesProvider).identity)) {
      return false;
    }
    await _keep(current.showing(map: map));
    return true;
  }

  /// The person read who the map provider is and chose the map. #3689 —
  /// the public-page editor accepts without switching Discover's view.
  Future<void> acceptMap({bool show = true}) async {
    final current = await future;
    final accepted = current.accepting(ref.read(mapServicesProvider).identity);
    await _keep(show ? accepted.showing(map: true) : accepted);
  }

  Future<void> _keep(DiscoveryViewPreference next) async {
    final namespace = await ref.read(savedPlacesNamespaceProvider.future);
    if (!ref.mounted) return;
    state = AsyncData(next);
    if (namespace == null) return;
    await ref.read(discoveryViewStoreProvider).write(namespace, next);
  }
}
