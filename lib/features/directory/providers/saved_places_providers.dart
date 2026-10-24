// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../workspace/providers/operation_context_providers.dart';
import '../data/prefs_saved_places_store.dart';
import '../domain/public_workspace.dart';
import '../domain/saved_place.dart';

part 'saved_places_providers.g.dart';

/// The device-local store of saved public pages.
@Riverpod(keepAlive: true)
SavedPlacesStore savedPlacesStore(Ref ref) => const PrefsSavedPlacesStore();

/// The namespace the signed-in person's saved places live under: their
/// canonical identity at their personal home. Null while nobody is signed
/// in there, so an anonymous visitor has nowhere to save to and sees no
/// one else's list. A selected workspace does not enter into it.
@riverpod
Future<String?> savedPlacesNamespace(Ref ref) async {
  final personal = await ref.watch(personalContextProvider.future);
  if (personal == null) return null;
  return savedPlacesNamespaceOf(
    issuer: personal.identity.issuer,
    subject: personal.identity.subject,
    home: personal.homeInstallationId,
  );
}

/// The person's saved places on this device; empty while signed out.
@riverpod
class SavedPlaces extends _$SavedPlaces {
  @override
  Future<List<SavedPlace>> build() async {
    final store = ref.watch(savedPlacesStoreProvider);
    final namespace = await ref.watch(savedPlacesNamespaceProvider.future);
    if (namespace == null) return const [];
    return store.read(namespace);
  }

  /// Saves [workspace]'s page, or removes it when it is saved. The list
  /// changes at once; the device write follows. Nothing happens without
  /// a namespace to write under.
  Future<void> toggle(PublicWorkspace workspace) async {
    final namespace = await ref.read(savedPlacesNamespaceProvider.future);
    if (namespace == null) return;
    final current = await future;
    final next = current.any((p) => p.matches(workspace))
        ? [for (final p in current) if (!p.matches(workspace)) p]
        : [...current, SavedPlace.of(workspace)];
    state = AsyncData(next);
    await ref.read(savedPlacesStoreProvider).write(namespace, next);
  }
}

/// Whether the discovery list shows only the places saved on this device.
@riverpod
class DiscoverSavedOnly extends _$DiscoverSavedOnly {
  @override
  bool build() => false;

  void toggle() => state = !state;
}
