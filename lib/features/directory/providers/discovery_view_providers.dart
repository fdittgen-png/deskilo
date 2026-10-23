// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/prefs_discovery_view_store.dart';
import '../domain/discovery_view.dart';
import 'saved_places_providers.dart';

part 'discovery_view_providers.g.dart';

/// The device-local store of the discovery view preference.
@Riverpod(keepAlive: true)
DiscoveryViewStore discoveryViewStore(Ref ref) =>
    const PrefsDiscoveryViewStore();

/// The map services this build draws discovery's map from.
@Riverpod(keepAlive: true)
MapServices mapServices(Ref ref) => MapServices.configured;

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
  /// provider already accepted.
  Future<void> show({required bool map}) async {
    final current = await future;
    if (map && !current.accepts(ref.read(mapServicesProvider).identity)) {
      return;
    }
    await _keep(current.showing(map: map));
  }

  /// The person read who the map provider is and chose the map.
  Future<void> acceptMap() async {
    final current = await future;
    await _keep(
      current
          .accepting(ref.read(mapServicesProvider).identity)
          .showing(map: true),
    );
  }

  Future<void> _keep(DiscoveryViewPreference next) async {
    final namespace = await ref.read(savedPlacesNamespaceProvider.future);
    if (!ref.mounted) return;
    state = AsyncData(next);
    if (namespace == null) return;
    await ref.read(discoveryViewStoreProvider).write(namespace, next);
  }
}
